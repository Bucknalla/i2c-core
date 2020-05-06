# I2C

The Inter-integrated Circuit (I2C), sometimes referred to as Two-Wire, is a 2 wire protocol that supports up to 1008 slave devices. 
I2C supports multiple master devices that can take turns controlling the bus.
Typically I2C operates at either 100 kHz or 400 kHz and contains a clock line, `SCL` and a data line, `SDA`. 
The `SCL` is always driven by the bus master.

![Fig 1. I2C Bus Diagram](/assets/images/i2c.png#center "Logo Title Text 1")

!!! note "Clock Stretching"
    Some slave devices may pull `SCL` low to pause the master from sending more data or to allow for more time to prepare output data, such as from reading a sensor, before the master attempts to clock it out. This is referred to as **clock stretching**.

Unlike UART or SPI connections, the I2C protocol is known as **open drain**; it can pull the corresponding signal line **low**, but cannot drive it high. 
This is designed to prevent any multiple master bus from causing bus contention (resulting in data loss and potential power issues), while another master is communicating.
Each signal line has a pull-up resistor, which restores the line to a **high** value when it is not communicating [@I2C_2013].

## Write Address

Certain I2C devices can be written to by only specifying the slave device's address. This performed by writing the I2C slave's address to `SDA`, awaiting an `ACK` signal and finally transmitting the intended data payload.

```wavedrom
{ 
    signal: [
        {  name: 'clk',  wave: 'p.......................|'},
        {  name: 'scl',  wave: '1...0.1.0.1.0.1.0.1.0.1.|'},
        {  name: 'sda',  wave: '1..0.3...3...3...3...3..|', data: ["Bit 7","Bit 6","Bit 5","Bit 4","Bit 3"]},
        {  name: 'mode', wave: 'x..4....................|', data: ["output","input"]},
        {  name: 'desc.',wave: '5..4.5..................|', data: ["Idle","Start","Data Transfer: 7 Bit Slave Address"]},
    ],
    head:{
        text:'Example I2C Write Address',
        tick:0,
    },
    config: { 
        hscale: 1,
        skin: "narrow" 
    }
}
```
```wavedrom
{ 
    signal: 
    [
        {  name: 'clk',  wave: 'p.......................|'},
        {  name: 'scl',  wave: '10.1.0.1.0.1.0.1.0.1.0.1|'},
        {  name: 'sda',  wave: '3.3...3...3...x3.x3...3.|', data: ["Bit 3","Bit 2","Bit 1","Bit 0","ACK","Bit 7","Bit 6"]},
        {  name: 'mode', wave: '4.............4...4.....|', data: ["output","input","output"]},
        {  name: 'desc.',wave: '5.........5...5...5.....|', data: ["Data Transfer: 7 Bit Slave Address","R/W","ACK/NAK","Data Transfer: 7 Bit Data"]},
    ],
    head:
    {
        tick:26,
    },
    config: { 
        hscale: 1 
    }
}
```
```wavedrom
{ 
    signal: 
    [
        {  name: 'clk',  wave: 'p.......................|'},
        {  name: 'scl',  wave: '10.1.0.1.0.1.0.1.0.1.0.1|'},
        {  name: 'sda',  wave: '3.3...3...3...3...3...3.|', data: ["Bit 6","Bit 5","Bit 4","Bit 3","Bit 2","Bit 1","Bit 0"]},
        {  name: 'mode', wave: '4.......................|', data: ["output"]},
        {  name: 'desc.',wave: '5.....................5.|', data: ["Data Transfer: 7 Bit Data","R/W"]},
    ],
    head:
    {
        tick:52,
    },
    config: { 
        hscale: 1 
    }
}
```
```wavedrom
{ 
    signal: 
    [
        {  name: 'clk',  wave: 'p........................'},
        {  name: 'scl',  wave: '10.1.0.1.................'},
        {  name: 'sda',  wave: '3.x3.x1..................', data: ["Bit 0","ACK"]},
        {  name: 'mode', wave: '4.4...x..................', data: ["output","input"]},
        {  name: 'desc.',wave: '5.5...4.5................', data: ["R/W","ACK/NAK","Stop","Idle"]},
    ],
    head:
    {
        tick:78,
    },
    foot:
    {
        text:"Figure 2.",
    },
    config: { 
        hscale: 1 
    }
}
```
## Write Register
```wavedrom
{ signal: [
    {  name: 'scl',  wave: 'p.............'},
    {  name: 'sda',  wave: '1..3.x.4x.....', data: 'A1 A2'},
],
head:{
   text:'I2C Write Addr',
   tick:0,
 },
 foot:{
   text:'Figure 0',
   tock:10
 },
config: { hscale: 1 }
}
```
## Read Address
```wavedrom
{ signal: [
    {  name: 'scl',  wave: 'p.............'},
    {  name: 'sda',  wave: 'x..3.x.4x.....', data: 'A1 A2'},
],
head:{
   text:'I2C Write Addr',
   tick:0,
 },
 foot:{
   text:'Figure 0',
   tock:10
 },
config: { hscale: 1 }
}
```
## Read Register
```wavedrom
{ signal: [
    {  name: 'scl',  wave: 'p.............'},
    {  name: 'sda',  wave: 'x..3.x.4x.....', data: 'A1 A2'},
],
head:{
   text:'I2C Write Addr',
   tick:0,
 },
 foot:{
   text:'Figure 0',
   tock:10
 },
config: { hscale: 1 }
}
```

## Notes
