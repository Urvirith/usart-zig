const std = @import("std");
const usart = @import("usart.zig");

pub fn main() anyerror!u8 {
    const port_name = "/dev/ttyUSB0";
    var buffer: [1024]u8 = undefined;

    var serial = std.fs.cwd().openFile(port_name, .{ .read = true, .write = true }) catch |err| switch (err) {
        error.FileNotFound => {
            try std.io.getStdOut().writer().print("The serial port {s} does not exist.\n", .{port_name});
            return 1;
        },
        else => return err,
    };
    defer serial.close();

    var config = usart.SerialPort.init(
        usart.BaudRate.baud921600, 
        usart.Parity.none, 
        usart.StopBits.one, 
        usart.WordLength.eight,
        usart.FlowControl.none
    );

    try config.configure(serial);

    //var i: u32 = 0;
    
    while (true) {
        //try serial.writer().writeAll("Hello, World!\r\n");

        //std.time.sleep(1000000000);
        var dog = try serial.reader().readUntilDelimiter(&buffer, 0x0D);

        try std.io.getStdOut().writer().print("Data: {d}\n", .{dog});
        //i+=1;
    }

    return 0;
}


