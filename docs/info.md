## How it works

This design implements an **SPI-controlled PWM peripheral** for Tiny Tapeout.  
It is made of two modules:

1. **SPI Peripheral**  
   - Listens to a 3-wire SPI bus (SCLK, COPI, nCS).  
   - Receives fixed 16-bit frames: `[1b R/W] [7b Address] [8b Data]`.  
   - Supports only write commands.  
   - Decodes the frame and updates one of five internal registers:  
     - `0x00`: Enable outputs uo_out[7:0]  
     - `0x01`: Enable outputs uio_out[7:0]  
     - `0x02`: Enable PWM on uo_out[7:0]  
     - `0x03`: Enable PWM on uio_out[7:0]  
     - `0x04`: Set PWM duty cycle (0x00 = 0%, 0xFF = 100%)  

2. **PWM Peripheral**  
   - Generates a ~3 kHz PWM signal from the 10 MHz system clock.  
   - Duty cycle is set by the register at address `0x04`.  
   - Each of the 16 outputs can be:  
     - Forced low,  
     - Forced high,  
     - Or driven by PWM, depending on the enable registers.  
   - Final outputs: `{uio_out[7:0], uo_out[7:0]}`  

---

## How to test

1. **Run the provided Cocotb SPI testbench**:
   - Tests that SPI writes correctly update internal registers.
   - Confirms invalid addresses are ignored.
   - Verifies PWM outputs toggle correctly.

   Run inside `test/`:
   ```bash
   make
