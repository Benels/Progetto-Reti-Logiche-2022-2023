The main goal of the project is to develope an FPGA which, given a serial input, represent in one of four output channels the datum that is being stored at the memory address given as input.


## Specifics of the project
The input will have a dimension ranging between 2 and 18 bits. The first two bits, always present, determine which of the four output channels (Z0, Z1, Z2, Z3) will display the data. The remaining bits, which dimension will be varying between 0 and 16, represent the RAM address from which to fetch the data to be shown on the specified output channel.
The provided specification outlines the behavior of the start signal **i_start**. This signal remains high for at least 2 clock cycles but cannot stay high for more than 18 clock cycles. While **i_start** is high, the system reads the input from **i_w**. Additionally, the reset signal **i_rst** can go high at any time, independently of the **i_start** signal or the clock signal. When **i_rst** is asserted, the system resets, disregarding any ongoing operations.

The project was developed for the **Reti Logiche** course held at Politecnico di Milano
