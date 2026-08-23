const std = @import("std");
const Io = std.Io;

// --- Цвета --- //
const RESET = "\x1b[0m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const MAGENTA = "\x1b[35m";
const CYAN = "\x1b[36m";

const help_table = [_]struct {
    usage: []const u8,
    desc: []const u8
} {
    .{ .usage = "help",             .desc = "показать эту справку" },
    .{ .usage = "echo <текст>",     .desc = "напечатать текст обратно" },
    .{ .usage = "add <a> <b>",      .desc = "сложить два целых числа" },
    .{ .usage = "mul <a> <b>",      .desc = "умножить два целых числа" },
    .{ .usage = "upper <текст>",    .desc = "текст В ВЕРХНЕМ РЕГИСТРЕ" },
    .{ .usage = "reverse <текст>",  .desc = "перевернуть строку (побайтово)" },
    .{ .usage = "lower <текст>",    .desc = "переводит текст в нижний регистр" },
    .{ .usage = "len <текст>",      .desc = "длина строки в байтах (UTF-8)" },
    .{ .usage = "env <ИМЯ>",        .desc = "показать переменную окружения" },
    .{ .usage = "args",             .desc = "показать аргументы командной строки" },
    .{ .usage = "run <prog> [arg]", .desc = "запустить внешнюю программу" },
    .{ .usage = "clear",            .desc = "очистить экран терминала" },
    .{ .usage = "exit",             .desc = "выйти из PhoenixShell" },
    .{ .usage = "fetch",            .desc = "как neofetch или nitch но для PhoenixShell" },
    .{ .usage = "ver",              .desc = "показывает версию PhoenixShell" },
    .{ .usage = "list",             .desc = "выводит файлы в текущей папке" },
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
        try stdout.print("PhoenixShell: '{s}' — не целое число\n", .{a_str});
        return;
    };
    const b = std.fmt.parseInt(i64, b_str, 10) catch {
        try stdout.print("PhoenixShell: '{s}' — не целое число\n", .{b_str});
        return;
    };

    const result = switch (op) {
        .add => std.math.add(i64, a, b),
        .mul => std.math.mul(i64, a, b),
    } catch {
        try stdout.writeAll("PhoenixShell: переполнение i64!\n");
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
pub fn cmdUpper(
    stdout: *Io.Writer,
    text: []const u8
) Io.Writer.Error !void {
    if (text.len == 0) {
        return stdout.writeAll("  синтаксис: upper <текст>\n");
    }
    if (text.len > 1024) {
        return stdout.writeAll("dltsh: текст слишком длинный\n");
    }

    var buf: [1024]u8 = undefined;
    for (text, 0..) |c, i| {
        buf[i] = if (c >= 'a' and c <= 'z') c + 'A' - 'a' else c;
    }
    try stdout.print("{s}\n", .{buf[0..text.len]});
}

pub fn cmdLower(
    stdout: *Io.Writer,
    text: []const u8
) Io.Writer.Error !void {
    if (text.len == 0) {
        return stdout.writeAll("  синтаксис: lower <текст>\n");
    }
    if (text.len > 1024) {
        return stdout.writeAll("dltsh: текст слишком длинный\n");
    }

    var buf: [1024]u8 = undefined;
    for (text, 0..) |c, i| {
        buf[i] = if (c >= 'A' and c <= 'Z') c + 'a' - 'A' else c;
    }
    try stdout.print("{s}\n", .{buf[0..text.len]});
}

pub fn cmdReverse(
    stdout: *Io.Writer,
    text: []const u8
) Io.Writer.Error !void {
    if (text.len == 0) {
        return stdout.writeAll("  синтаксис: reverse <текст>\n");
    }

    if (text.len > 1024) {
        return stdout.writeAll("PhoenixShell: текст слишком длинный\n");
    }

    var buf: [1024]u8 = undefined;
    for (text, 0..) |c, i| {
        buf[text.len - 1 - i] = c;
    }
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
    } else {
        try stdout.print("PhoenixShell: переменная '{s}' не установлена\n", .{name});
    }
}

pub fn cmdFetch(stdout: *Io.Writer) !void {
    try stdout.print("{s} _______ {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} |     | {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} | ___ | {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} | |_| | {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} | ____|                                     __    __{s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} | | ___     _________ _____ __ __   ___ ___ \\ \\  / /   {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} | | | |___  |  ___  | |   | | |\\ \\  | | | |  \\_\\/_/  {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} | | | |_| | |  |_|  | |___| | | \\ \\ | | | |  / /\\ \\  {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} |_| |_| |_| |_______| |____ |_|  \\_\\|_| |_| /_/  \\_\\ {s}\n", .{ YELLOW, RESET });

    try stdout.print("{s} ================================================================ {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} [USER]:  [deltaqxq]         {s}\n", .{ YELLOW, RESET }); // Ну или ваш какой-нибудь юзер
    try stdout.print("{s} [OS]:    [neplohoy-os]      {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} [HOST]:  [mega-krutoy-komp] {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} [Shell]: [PhoenixShell (Zig) v0.1.0] {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} [CPU]:   [potato-cpu-5000] {s}\n", .{ YELLOW, RESET });
    try stdout.print("{s} [GPU]:   [ventilator-3000] {s}\n", .{ YELLOW, RESET });
}

pub fn cmdVersion(stdout: *Io.Writer) !void {
    try stdout.print("{s} PhoenixShell v0.1.0 {s} \n", .{ YELLOW, RESET });
}

pub fn cmdList(
    stdout: *Io.Writer,
    init: std.process.Init
) !void {
    const io = init.io;

    var dir = std.Io.Dir.cwd().openDir(io, ".", .{.iterate = true}) catch {
        try stdout.print("{s} Не удалось открыть текущую папку. {s}\n", .{ RED, RESET });
        return;
    };

    defer dir.close(io);

    try stdout.print("{s} Файлы в текущей папке: {s}\n", .{ YELLOW, RESET });

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.name[0] != '.') {
            try stdout.print("{s}\n", .{ entry.name });
        }
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
        try stdout.print("PhoenixShell: не удалось запустить '{s}': {s}\n", .{
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
