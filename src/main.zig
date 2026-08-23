const std = @import("std");
const Io = std.Io;
const shell = @import("commands.zig");

const banner =
    \\ |=========================================|
    \\ |  PhoenixShell v0.1.0 (на Zig 0.16.0)    |
    \\ |  Введите 'help', чтобы увидеть команды. |
    \\ |=========================================|
    \\
;

const prompt = "> ";

const Command = enum {
    help,
    echo,
    add,
    mul,
    upper,
    reverse,
    len,
    env,
    args,
    run,
    clear,
    exit,
    fetch,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    var in_buf: [4096]u8 = undefined;
    var stdin_impl = Io.File.stdin().reader(io, &in_buf);
    const input = &stdin_impl.interface;

    var out_buf: [4096]u8 = undefined;
    var stdout_impl = Io.File.stdout().writer(io, &out_buf);
    const output = &stdout_impl.interface;

    try output.writeAll(banner);

    while (true) {
        try output.writeAll(prompt);
        try output.flush();

        const line = readLine(input) catch |err| switch (err) {
            error.LineTooLong => {
                try output.writeAll("dltsh: строка слишком длинная (>4095)\n");
                continue;
            },
            error.ReadFailed => return err,
        }
        orelse {
            try output.writeAll("\n");
            break;
        };

        const command_line = std.mem.trim(u8, line, " \t\r");
        if (command_line.len == 0) continue;

        var words = std.mem.tokenizeScalar(u8, command_line, ' ');
        const name = words.next().?;
        const rest = std.mem.trim(u8, command_line[name.len..], " \t");

        const cmd = std.meta.stringToEnum(Command, name) orelse {
            try output.print("dltsh: неизвестная команда '{s}'. Введите 'help'.\n", .{name});
            continue;
        };

        switch (cmd) {
            .help  => try shell.cmdHelp(output),
            .fetch => try shell.cmdFetch(output),
            .exit  => break,
            .clear => try output.writeAll("\x1b[2J\x1b[3J\x1b[H"),
            .echo  => try output.print("{s}\n", .{rest}),
            .add   => try shell.cmdCalc(output, &words, .add),
            .mul   => try shell.cmdCalc(output, &words, .mul),
            .upper => try shell.cmdUpper(output, rest),
            .reverse => try shell.cmdReverse(output, rest),
            .len     => try output.print("{d} байт\n", .{rest.len}),
            .env     => try shell.cmdEnv(output, init, rest),
            .args    => try shell.cmdArgs(output, init, arena),
            .run     => try shell.cmdRun(output, io, gpa, &words, rest),
        }

        try output.flush();
    }

    try output.writeAll("Goodbye!\n");
    try output.flush();
}

const ReadLineError = error {
    LineTooLong,
    ReadFailed
};

fn readLine(reader: *Io.Reader) ReadLineError !? []u8 {
    if (reader.takeDelimiterExclusive('\n')) |line| {
        reader.toss(1);
        return line;
    }
    else |err| switch (err) {
        error.EndOfStream => {
            const tail = reader.buffered();
            if (tail.len == 0) {
                return null;
            }

            reader.toss(tail.len);
            return tail;
        },
        error.StreamTooLong => {
            while (true) {
                reader.toss(reader.bufferedLen());
                if (reader.takeDelimiterExclusive('\n')) |_| {
                    reader.toss(1);
                    break;
                }
                else |err2| switch (err2) {
                    error.StreamTooLong => continue,
                    error.EndOfStream   => break,
                    error.ReadFailed    => return error.ReadFailed,
                }
            }
            return error.LineTooLong;
        },
        error.ReadFailed => return error.ReadFailed,
    }
}
