const std = @import("std");
const usart = @import("usart.zig");

pub fn main() anyerror!u8 {
    const port_name = "/dev/ttyUSB0";

    var serial = std.fs.cwd().openFile(port_name, .{ .read = true, .write = true }) catch |err| switch (err) {
        error.FileNotFound => {
            try std.io.getStdOut().writer().print("The serial port {s} does not exist.\n", .{port_name});
            return 1;
        },
        else => return err,
    };
    defer serial.close();

    var config = usart.SerialPort.init(
        usart.BaudRate.baud9600, 
        usart.Parity.none, 
        usart.StopBits.one, 
        usart.WordLength.seven,
        usart.FlowControl.none
    );

    try config.configure(serial);

    try serial.writer().writeAll("Hello, World!\r\n");
    return 0;
}


