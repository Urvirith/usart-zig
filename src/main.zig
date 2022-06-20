const std = @import("std");
const usart = @import("usart.zig");

pub fn main() anyerror!u8 {    
    const port_name = "/dev/ttyUSB0";
    var buffer: [1024]u8 = undefined;

    var dev = std.fs.cwd().openFile(port_name, .{ .read = true, .write = true }) catch |err| switch (err) {
        error.FileNotFound => {
            try std.io.getStdOut().writer().print("The serial port {s} does not exist.\n", .{port_name});
            return 1;
        },
        else => return err,
    };
    defer dev.close();

    var config = usart.SerialPort.init(
        usart.BaudRate.baud4800, 
        usart.Parity.none, 
        usart.StopBits.one, 
        usart.WordLength.eight,
        usart.FlowControl.none
    );

    try config.configure(dev);
    
    while (true) {
        try dev.writer().writeAll("Hello, World!\n");

        std.time.sleep(1000000000);
        var len = try dev.reader().readUntilDelimiter(&buffer, '\n');

        try std.io.getStdOut().writer().print("Data: {s}\n", .{len});
    }

    return 0;
}
