// my_incl.vh
// If we have not included file before, 
// this symbol _my_incl_vh_ is not defined.
`ifndef _i2c_defines_
`define _i2c_defines_
// Start of include contents
`define N 4
// Use parentheses to mitigate any undesired operator precedence issues
`define M (`N << 2)
`endif  
//_my_incl_vh_