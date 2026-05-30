const std = @import("std");
const Io = std.Io;
const print = std.debug.print;

const dumb_xxd = @import("dumb_xxd");

const Input = union(enum) {
    stdin: void,
    file: [:0]const u8,
};

const Output = union(enum) {
    stdout: void,
    file: [:0]const u8,
};

const ParsedArgs = struct {
    output: Output,
    input: Input,
};

fn parseArgs(args: std.process.Args) !ParsedArgs {
    var iter = args.iterate();
    _ = iter.skip();

    var parsed: ParsedArgs = .{ .input = .stdin, .output = .stdout };

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o")) {
            const file = iter.next() orelse unreachable;
            parsed.output = .{ .file = file };
            continue;
        }
        parsed.input = .{ .file = arg };
    }

    return parsed;
}

fn printBar(chunk: []u8, writer: *std.Io.Writer, sum: u32) !void {
    _ = try writer.print("{x:0>8}: ", .{
        sum,
    });

    var middle_text_buf: [64]u8 = undefined;
    var window = std.mem.window(u8, chunk, 2, 2);

    var middle_text_writer: std.Io.Writer = .fixed(&middle_text_buf);

    while (window.next()) |bytes| {
        try middle_text_writer.print("{x} ", .{bytes});
    }
    _ = try writer.print("{s: <40}", .{middle_text_writer.buffered()});

    var sanitized: [64]u8 = undefined;
    _ = std.mem.replace(u8, chunk, "\n", ".", &sanitized);
    _ = try writer.print(" {s}\n", .{sanitized[0..chunk.len]});
}

pub fn main(init: std.process.Init) !void {
    const args = try parseArgs(init.minimal.args);
    const io = init.io;

    var out_buf: [4096]u8 = undefined;
    var out_file: ?Io.File = null;
    defer if (out_file) |f| f.close(io);

    var output_writer: Io.File.Writer = switch (args.output) {
        .stdout => .init(.stdout(), io, &out_buf),
        .file => |path| blk: {
            out_file = try std.Io.Dir.cwd().createFile(io, path, .{});
            break :blk out_file.?.writer(io, &out_buf);
        },
    };
    defer output_writer.flush() catch {};
    var writer = &output_writer.interface;

    var in_buf: [4096]u8 = undefined;
    var in_file: ?Io.File = null;
    defer if (in_file) |f| f.close(io);

    var input_reader: Io.File.Reader = switch (args.input) {
        .stdin => .init(.stdin(), io, &in_buf),
        .file => |path| blk: {
            in_file = try Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
            break :blk in_file.?.reader(io, &in_buf);
        },
    };
    var reader = &input_reader.interface;

    var process_buf: [16]u8 = undefined;
    var sum: u32 = 0;
    while (true) {
        const bytes = reader.readSliceShort(&process_buf) catch |err| {
            return err;
        };
        if (bytes == 0) {
            break;
        }
        const chunk = process_buf[0..bytes];
        try printBar(chunk, writer, sum);
        sum += @intCast(bytes);
    }
    _ = try writer.flush();
}
