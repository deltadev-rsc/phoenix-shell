const std = @import("std");
const Io = std.Io;

const help_table = [_]struct { usage: []const u8, desc: []const u8 }{
    .{ .usage = "help", .desc = "показать эту справку" },
    .{ .usage = "echo <текст>", .desc = "напечатать текст обратно" },
    .{ .usage = "add <a> <b>", .desc = "сложить два целых числа" },
    .{ .usage = "mul <a> <b>", .desc = "умножить два целых числа" },
    .{ .usage = "upper <текст>", .desc = "текст В ВЕРХНЕМ РЕГИСТРЕ" },
    .{ .usage = "reverse <текст>", .desc = "перевернуть строку (побайтово)" },
    .{ .usage = "len <текст>", .desc = "длина строки в байтах (UTF-8)" },
    .{ .usage = "env <ИМЯ>", .desc = "показать переменную окружения" },
    .{ .usage = "args", .desc = "показать аргументы командной строки" },
    .{ .usage = "run <prog> [arg]", .desc = "запустить внешнюю программу" },
    .{ .usage = "clear", .desc = "очистить экран терминала" },
    .{ .usage = "exit", .desc = "выйти из dltsh" },
};

pub fn cmdHelp(stdout: *Io.Writer) !void {
    try stdout.writeAll("\nДоступные команды:\n\n");
    for (&help_table) |row| {
        try stdout.print("  {s:<17} — {s}\n", .{ row.usage, row.desc });
    }
    try stdout.writeAll("\n");
}

// --- Для команд add и mul --- //
const CalcOp = enum { add, mul };

pub fn cmdCalc(
    stdout: *Io.Writer,
    words: *std.mem.TokenIterator(u8, .scalar),
    op: CalcOp,
) !void {
    const a_str = words.next() orelse return printCalcUsage(stdout, op);
    const b_str = words.next() orelse return printCalcUsage(stdout, op);

    const a = std.fmt.parseInt(i64, a_str, 10) catch {
        try stdout.print("dltsh: '{s}' — не целое число\n", .{a_str});
        return;
    };
    const b = std.fmt.parseInt(i64, b_str, 10) catch {
        try stdout.print("dltsh: '{s}' — не целое число\n", .{b_str});
        return;
    };

    // std.math.add / mul сами отслеживают переполнение i64
    const result = switch (op) {
        .add => std.math.add(i64, a, b),
        .mul => std.math.mul(i64, a, b),
    } catch {
        try stdout.writeAll("dltsh: переполнение i64!\n");
        return;
    };

    const symbol: []const u8 = if (op == .add) "+" else "*";
    try stdout.print("{d} {s} {d} = {d}\n", .{ a, symbol, b, result });
}

fn printCalcUsage(stdout: *Io.Writer, op: CalcOp) Io.Writer.Error!void {
    try stdout.print("  синтаксис: {s} <a> <b>\n", .{@tagName(op)});
}

// --- команды для вывода текста. --- //
// --- перевод его в верхний регистр или переворачиавание слева направо --- //
pub fn cmdUpper(stdout: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    if (text.len == 0) return stdout.writeAll("  синтаксис: upper <текст>\n");
    if (text.len > 1024) return stdout.writeAll("dltsh: текст слишком длинный\n");

    var buf: [1024]u8 = undefined;
    for (text, 0..) |c, i| {
        buf[i] = if (c >= 'a' and c <= 'z') c + 'A' - 'a' else c;
    }
    try stdout.print("{s}\n", .{buf[0..text.len]});
}

pub fn cmdReverse(stdout: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    if (text.len == 0) return stdout.writeAll("  синтаксис: reverse <текст>\n");
    if (text.len > 1024) return stdout.writeAll("dltsh: текст слишком длинный\n");

    var buf: [1024]u8 = undefined;
    for (text, 0..) |c, i| buf[text.len - 1 - i] = c;
    try stdout.print("{s}\n", .{buf[0..text.len]});
}

//--- Всякие базовые команды ---//
pub fn cmdEnv(
    stdout: *Io.Writer, 
    init: std.process.Init, 
    name: []const u8
) Io.Writer.Error !void {
    if (name.len == 0) { 
        return stdout.writeAll("  синтаксис: env <ИМЯ>\n");
    }

    if (init.environ_map.get(name)) |value| {
        try stdout.print("{s}={s}\n", .{ name, value });
    } 
    else {
        try stdout.print("dltsh: переменная '{s}' не установлена\n", .{name});
    }
}

pub fn cmdArgs(
    stdout: *Io.Writer,
    init: std.process.Init, 
    arena: std.mem.Allocator
) !void {
    const argv = try init.minimal.args.toSlice(arena);
    for (argv, 0..) |arg, i| {
        try stdout.print("argv[{d}] = {s}\n", .{ i, arg });
    }
}

pub fn cmdRun(
    stdout: *Io.Writer,
    io: Io,
    gpa: std.mem.Allocator,
    words: *std.mem.TokenIterator(u8, .scalar),
    rest: []const u8,
) !void {
    if (rest.len == 0) {
        return stdout.writeAll("  синтаксис: run <программа> [аргументы...]\n");
    }

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(gpa);
    while (words.next()) |w| try argv.append(gpa, w);

    const result = std.process.run(gpa, io, .{
        .argv = argv.items,
    }) catch |err| {
        try stdout.print("dltsh: не удалось запустить '{s}': {s}\n", .{
            argv.items[0], @errorName(err),
        });
        return;
    };
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    try stdout.writeAll(result.stdout);
    try stdout.writeAll(result.stderr);

    switch (result.term) {
        .exited => |code| if (code != 0) {
            try stdout.print("[код завершения: {d}]\n", .{code});
        },
        .signal => |sig| try stdout.print("[убито сигналом {d}]\n", .{sig}),
        else => {},
    }
}
