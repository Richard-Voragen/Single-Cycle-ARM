//```````````````````````````````````````````````````````````````
// arm_single.v
// David_Harris@hmc.edu and Sarah_Harris@hmc.edu 25 June 2013
//
// Single-cycle implementation of a subset of ARMv4
// 
// run 210
// Expect simulator to print "Simulation succeeded"
// when the value 7 is written to address 100 (0x64)

// 16 32-bit registers
// Data-processing instructions
//   ADD, SUB, AND, ORR
//   INSTR<cond><S> rd, rn, #immediate
//   INSTR<cond><S> rd, rn, rm
//    rd <- rn INSTR rm	      if (S) Update Status Flags
//    rd <- rn INSTR immediate	if (S) Update Status Flags
//   Instr[31:28] = cond
//   Instr[27:26] = op = 00
//   Instr[25:20] = funct
//                  [25]:    1 for immediate, 0 for register
//                  [24:21]: 0100 (ADD) / 0010 (SUB) /
//                           0000 (AND) / 1100 (ORR) / 
//                           0001 (EOR) / 0011 (CMP)
//                  [20]:    S (1 = update CPSR status Flags)
//   Instr[19:16] = rn (register number)
//   Instr[15:12] = rd (register destination)
//   Instr[11:8]  = 0000 
//   Instr[11:7]  = Shift Amount (if Register)
//   Instr[6:5]   = Shift Direction (if Register) 01 for right, 10 for left
//   Instr[7:0]   = imm8      (for #immediate type) / 
//                  {0000,rm} (for register type) 
//   
// Load/Store instructions
//   LDR, STR
//   INSTR rd, [rn, #offset]
//    LDR: rd <- Mem[rn+offset]
//    STR: Mem[rn+offset] <- rd
//   Instr[31:28] = cond
//   Instr[27:26] = op = 01 
//   Instr[25:20] = funct
//                  [25]:    0 (A)
//                  [24:21]: 1100 (P/U/B/W)
//                  [20]:    L (1 for LDR, 0 for STR)
//   Instr[19:16] = rn
//   Instr[15:12] = rd
//   Instr[11:0]  = imm12 (zero extended)
//
// Branch instruction (PC <= PC + offset, PC holds 8 bytes past Branch Instr)
//   B
//   B target
//    PC <- PC + 8 + imm24 << 2
//   Instr[31:28] = cond
//   Instr[27:25] = op = 10
//   Instr[25:24] = funct
//                  [25]: 1 (Branch)
//                  [24]: 0 (link)
//   Instr[23:0]  = imm24 (sign extend, shift left 2)
//   Note: no Branch delay slot on ARM
//
// Shift instructions
//   Instr[31:28] = cond
//   Instr[27:25] = op = 11
//   Instr[25:20] = funct
//                  [25]:   1 for immediate, 0 for register
//                  [24:23] 01 (Right shift)
//                  [24:23] 10 (Left shift)
//                  [22:20] 000
//   Instr[19:16] = rn
//   Instr[15:12] = rd
//   Instr[11:5] = 000000
//   Instr[4:0] = Imm5
//                [0] + Reg
//
// Other:
//   R15 reads as PC+8
//   Conditional Encoding
//    cond  Meaning                       Flag
//    0000  Equal                         Z = 1
//    0001  Not Equal                     Z = 0
//    0010  Carry Set                     C = 1
//    0011  Carry Clear                   C = 0
//    0100  Minus                         N = 1
//    0101  Plus                          N = 0
//    0110  Overflow                      V = 1
//    0111  No Overflow                   V = 0
//    1000  Unsigned Higher               C = 1 & Z = 0
//    1001  Unsigned Lower/Same           C = 0 | Z = 1
//    1010  Signed greater/equal          N = V
//    1011  Signed less                   N != V
//    1100  Signed greater                N = V & Z = 0
//    1101  Signed less/equal             N != V | Z = 1
//    1110  Always                        any

//```````````````````````````````````````````````````````````````
module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;

  //````````````````````````````````````````````````
  // instantiate device to be tested
  top dut(clk, reset, WriteData, DataAdr, MemWrite);
  
  //````````````````````````````````````````````````
  // initialize test
  initial
    begin
      reset <= 1; # 22; reset <= 0;
    end

  //````````````````````````````````````````````````
  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  //````````````````````````````````````````````````
  // check results
  always @(negedge clk)
    begin
      if(MemWrite) begin
        if(DataAdr === 128 && WriteData === 254) begin
          $display("Simulation succeeded");
          $stop;
        end else if (DataAdr !== 96) begin
          //$display("Simulation failed");
          //$stop;
        end
      end
    end
endmodule

//```````````````````````````````````````````````````````````````
module top(input  logic        clk, reset, 
           output logic [31:0] WriteData, DataAdr, 
           output logic        MemWrite);

  logic [31:0] PC, Instr, ReadData;
  
  //````````````````````````````````````````````````
  // instantiate processor and memories
  //
  arm arm(clk, reset, PC, Instr, MemWrite, DataAdr, 
          WriteData, ReadData);

  //```````````````````````
  // instruction memory
  //
  imem imem(PC, Instr);

  //```````````````````````
  // data memory
  //
  dmem dmem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule

//```````````````````````````````````````````````````````````````
module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule

//```````````````````````````````````````````````````````````````
// the instruction memory loads memfile.dat into RAM
// to be executed
//
module imem(input  logic [31:0] a,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("memfile3.dat",RAM);

  assign rd = RAM[a[31:2]]; // word aligned
endmodule

//```````````````````````````````````````````````````````````````
// This module is the arm CPU
//
module arm(input  logic        clk, reset,
           output logic [31:0] PC,
           input  logic [31:0] Instr,
           output logic        MemWrite,
           output logic [31:0] ALUResult, WriteData,
           input  logic [31:0] ReadData);

  logic [3:0] ALUFlags;
  logic       RegWrite, 
              ALUSrc, MemtoReg, PCSrc;
  logic [1:0] RegSrc, ImmSrc, ShiftDirection;
  logic [2:0] ALUControl;
  logic Lower8Bit;

  controller c(clk, reset, Instr[31:12], ALUFlags, 
               RegSrc, RegWrite, ImmSrc, ShiftDirection,
               ALUSrc, ALUControl,
               MemWrite, MemtoReg, PCSrc, Lower8Bit);

  datapath dp(clk, reset, 
              RegSrc, RegWrite, ImmSrc, ShiftDirection,
              ALUSrc, ALUControl,
              MemtoReg, PCSrc,
              ALUFlags, PC, Instr,
              ALUResult, WriteData, ReadData, Lower8Bit);
endmodule

//```````````````````````````````````````````````````````````````
// The controller takes in the bits that define the instruction
// and outputs all of the control signals to control the 
// execution of each instruction
//
module controller(input  logic         clk, reset,
	              input  logic [31:12] Instr,
                  input  logic [3:0]   ALUFlags,
                  output logic [1:0]   RegSrc,
                  output logic         RegWrite,
                  output logic [1:0]   ImmSrc, ShiftDirection,
                  output logic         ALUSrc, 
                  output logic [2:0]   ALUControl,
                  output logic         MemWrite, MemtoReg,
                  output logic         PCSrc, Lower8Bit);

  logic [1:0] FlagW;
  logic       PCS, RegW, MemW, NoWrite;
  
  decode dec(Instr[27:26], Instr[25:20], Instr[15:12],
             FlagW, PCS, RegW, MemW,
             MemtoReg, ALUSrc, ImmSrc, RegSrc, ShiftDirection, ALUControl, Lower8Bit, NoWrite);
  condlogic cl(clk, reset, Instr[31:28], ALUFlags,
               FlagW, PCS, RegW, MemW, NoWrite,
               PCSrc, RegWrite, MemWrite);
endmodule

//```````````````````````````````````````````````````````````````
module decode(input  logic [1:0] Op,
              input  logic [5:0] Funct,
              input  logic [3:0] Rd,
              output logic [1:0] FlagW,
              output logic       PCS, RegW, MemW,
              output logic       MemtoReg, ALUSrc,
              output logic [1:0] ImmSrc, RegSrc, ShiftDirection,
              output logic [2:0] ALUControl,
              output logic Lower8Bit, NoWrite);

  logic [9:0] controls;
  logic       Branch, ALUOp, L8B;

  //```````````````````````
  // Main Decoder
  //    
  always_comb
  	casex(Op)
  	                        // Data processing immediate
  	  2'b00: if (Funct[5])  controls = 10'b0000101001;
  	                        // Data processing register
  	         else           controls = 10'b0000001001;
  	                        // LDR
  	  2'b01: if (Funct[0])  controls = 10'b0001111000; 
                            // STR
             else           controls = 10'b1001110100;
  	                        // B
  	  2'b10:                controls = 10'b0110100010;
                            // LSL LSR Immediate
      2'b11: if (Funct[5])  controls = 10'b0000101000;
                            // LSL LSR Register
             else           controls = 10'b0000001000;
  	                        // Unimplemented
  	  default:              controls = 10'bx;          
  	endcase

  assign {RegSrc, ImmSrc, ALUSrc, MemtoReg, 
          RegW, MemW, Branch, ALUOp} = controls; 
          
  //```````````````````````
  // ALU Decoder             
  //
  always_comb
    if (ALUOp) begin                 // which DP Instr?
      case(Funct[4:1]) 
  	    4'b0100: ALUControl = 3'b100; // ADD
  	    4'b0010: ALUControl = 3'b101; // SUB
        4'b0000: ALUControl = 3'b110; // AND
  	    4'b1100: ALUControl = 3'b111; // ORR
        4'b0001: ALUControl = 3'b010; // XOR
        4'b0011: ALUControl = 3'b101; // CMP
  	    default: ALUControl = 3'bx;  // unimplemented
      endcase
      // update flags if S bit is set 
	// (C & V only updated for arith instructions)
      FlagW[1]      = Funct[0]; // FlagW[1] = S-bit
	// FlagW[0] = S-bit & (ADD | SUB)
      FlagW[0]      = Funct[0] & 
        (ALUControl == 3'b100 | ALUControl == 3'b101);

      if (ALUOp == 4'b0011) begin
        FlagW = 2'b11; 
        NoWrite = 0;
      end else NoWrite = 1;
    end else begin
      ALUControl = 3'b100; // add for non-DP instructions
      FlagW      = 2'b00; // don't update Flags
      $display(Op);
      if (Op == 2'b01) begin
        if (Funct[2]) L8B = 1;
      end else if (Op == 2'b11) begin
        $display(Op);
        if (Funct[3]) ShiftDirection = 2'b01;
        else ShiftDirection = 2'b10;
      end else begin
        L8B = 0;
        ShiftDirection = 2'b00;
      end
    end
              
  //```````````````````````
  // PC Logic
  //
  assign PCS  = ((Rd == 4'b1111) & RegW) | Branch; 
  assign Lower8Bit = L8B;
endmodule

//```````````````````````````````````````````````````````````````
module condlogic(input  logic       clk, reset,
                 input  logic [3:0] Cond,
                 input  logic [3:0] ALUFlags,
                 input  logic [1:0] FlagW,
                 input  logic       PCS, RegW, MemW, NoWrite,
                 output logic       PCSrc, RegWrite, MemWrite);
                 
  logic [1:0] FlagWrite;
  logic [3:0] Flags;
  logic       CondEx;

  flopenr #(2)flagreg1(clk, reset, FlagWrite[1], 
                       ALUFlags[3:2], Flags[3:2]);
  flopenr #(2)flagreg0(clk, reset, FlagWrite[0], 
                       ALUFlags[1:0], Flags[1:0]);

  //```````````````````````
  // write controls are conditional
  //
  condcheck cc(Cond, Flags, CondEx);
  assign FlagWrite = FlagW & {2{CondEx}};
  assign RegWrite  = RegW  & CondEx & NoWrite;
  assign MemWrite  = MemW  & CondEx & NoWrite;
  assign PCSrc     = PCS   & CondEx & NoWrite;
endmodule    

//```````````````````````````````````````````````````````````````
module condcheck(input  logic [3:0] Cond,
                 input  logic [3:0] Flags,
                 output logic       CondEx);
  
  logic neg, zero, carry, overflow, ge;
  
  assign {neg, zero, carry, overflow} = Flags;
  assign ge = (neg == overflow);
                  
  always_comb
    case(Cond)
      4'b0000: CondEx = zero;             // EQ
      4'b0001: CondEx = ~zero;            // NE
      4'b0010: CondEx = carry;            // CS
      4'b0011: CondEx = ~carry;           // CC
      4'b0100: CondEx = neg;              // MI
      4'b0101: CondEx = ~neg;             // PL
      4'b0110: CondEx = overflow;         // VS
      4'b0111: CondEx = ~overflow;        // VC
      4'b1000: CondEx = carry & ~zero;    // HI
      4'b1001: CondEx = ~(carry & ~zero); // LS
      4'b1010: CondEx = ge;               // GE
      4'b1011: CondEx = ~ge;              // LT
      4'b1100: CondEx = ~zero & ge;       // GT
      4'b1101: CondEx = ~(~zero & ge);    // LE
      4'b1110: CondEx = 1'b1;             // Always
      default: CondEx = 1'bx;             // undefined
    endcase
endmodule

//```````````````````````````````````````````````````````````````
module datapath(input  logic        clk, reset,
                input  logic [1:0]  RegSrc,
                input  logic        RegWrite,
                input  logic [1:0]  ImmSrc, ShiftDirection,
                input  logic        ALUSrc,
                input  logic [2:0]  ALUControl,
                input  logic        MemtoReg,
                input  logic        PCSrc,
                output logic [3:0]  ALUFlags,
                output logic [31:0] PC,
                input  logic [31:0] Instr,
                output logic [31:0] ALUResult, WriteData,
                input  logic [31:0] ReadData,
                input  logic Lower8Bit);

  logic [31:0] PCNext, PCPlus4, PCPlus8;
  logic [31:0] ExtImm, SrcA, SrcB, Result;
  logic [3:0]  RA1, RA2;

  // next PC logic
  mux2 #(32)  pcmux(PCPlus4, Result, PCSrc, PCNext);
  flopr #(32) pcreg(clk, reset, PCNext, PC);
  adder #(32) pcadd1(PC, 32'b100, PCPlus4);
  adder #(32) pcadd2(PCPlus4, 32'b100, PCPlus8);

  // Shorten bits if needed
  logic [31:0] shortReadData, ReadDataMUXOut;
  always_comb begin
    if (ALUResult[1:0] == 2'b00) shortReadData = {24'b0, ReadData[7: 0]};
    else if (ALUResult[1:0] == 2'b01) shortReadData = {24'b0, ReadData[15: 8]};
    else if (ALUResult[1:0] == 2'b10) shortReadData = {24'b0, ReadData[23: 16]};
    else shortReadData = {24'b0, ReadData[31: 24]};
  end
  mux2 #(32)  outmux(ReadData, shortReadData, Lower8Bit, ReadDataMUXOut);

  // register file logic
  mux2 #(4)   ra1mux(Instr[19:16], 4'b1111, RegSrc[0], RA1);
  mux2 #(4)   ra2mux(Instr[3:0], Instr[15:12], RegSrc[1], RA2);
  regfile     rf(clk, RegWrite, RA1, RA2,
                 Instr[15:12], Result, PCPlus8, 
                 SrcA, WriteData); 
  mux2 #(32)  resmux(ALUResult, ReadDataMUXOut, MemtoReg, Result);

  extend      ext(Instr[23:0], ImmSrc, ExtImm, 1'b0);

  // ALU logic
  logic [31:0] WDataOut;
  logic [6:0] shiftData;
  always_comb begin
    if (ALUControl[1] == 0) shiftData = Instr[11:5];
    else shiftData = 7'b0000000;
  end
  shifter     shft(WriteData, shiftData[6:2], shiftData[1:0], WDataOut);
  mux2 #(32)  srcbmux(WDataOut, ExtImm, ALUSrc, SrcB);

  logic [31:0] ALURes, SHFTRes;
  shifter     lsLR(SrcA, SrcB[4:0], ShiftDirection, SHFTRes);

  alu         alu(SrcA, SrcB, ALUControl, 
                  ALURes, ALUFlags);

  mux2 #(32)  ALUorSHFT(ALURes, SHFTRes, (ShiftDirection[1] | ShiftDirection[0]), ALUResult);
endmodule

//```````````````````````````````````````````````````````````````
module regfile(input  logic        clk, 
               input  logic        we3, 
               input  logic [3:0]  ra1, ra2, wa3, 
               input  logic [31:0] wd3, r15,
               output logic [31:0] rd1, rd2);

  logic [31:0] rf[14:0];

  //```````````````````````
  // three ported register file
  // read two ports combinationally
  // write third port on rising edge of clock
  // register 15 reads PC+8 instead

  always_ff @(posedge clk)
    if (we3) rf[wa3] <= wd3;	

  assign rd1 = (ra1 == 4'b1111) ? r15 : rf[ra1];
  assign rd2 = (ra2 == 4'b1111) ? r15 : rf[ra2];

endmodule

//```````````````````````````````````````````````````````````````
module extend(input  logic [23:0] Instr,
              input  logic [1:0]  ImmSrc,
              output logic [31:0] ExtImm,
              input logic Lower8Bit);
 
  always_comb
    case(ImmSrc) 
               // 8-bit unsigned immediate
      2'b00:   ExtImm = {24'b0, Instr[7:0]};  
               // 12-bit unsigned immediate 
      2'b01:   ExtImm = {20'b0, Instr[11:0]}; 
               // 24-bit two's complement shifted branch 
      2'b10:   ExtImm = {{6{Instr[23]}}, Instr[23:0], 2'b00}; 
      default: ExtImm = 32'bx; // undefined
    endcase             
endmodule

//```````````````````````````````````````````````````````````````
module shifter(input logic [31:0] RD2,
               input logic [4:0] shiftAmt,
               input logic [1:0] shiftDir,
               output logic [31:0] RD2Out);
  int shift;
  always_comb begin
    shift = 0;
    if (shiftAmt[0] == 1) shift += 1;
    if (shiftAmt[1] == 1) shift += 2;
    if (shiftAmt[2] == 1) shift += 4;
    if (shiftAmt[3] == 1) shift += 8;
    if (shiftAmt[4] == 1) shift += 16;
  end

  always_comb begin
    if (shiftDir[0] == 1) begin
      for (int i = 31; i >= 0; i = i - 1) begin
        if (i + shift > 31) RD2Out[i] = 1'b0;
        else RD2Out[i] = RD2[i + shift];
      end
    end else if (shiftDir[1] == 1) begin
      for (int i = 0; i < 32; i = i + 1) begin
        if (i - shift < 0) RD2Out[i] = 1'b0;
        else RD2Out[i] = RD2[i - shift];
      end
    end else begin
      RD2Out = RD2;
    end
  end

endmodule

//```````````````````````````````````````````````````````````````
module adder #(parameter WIDTH=8)
              (input  logic [WIDTH-1:0] a, b,
               output logic [WIDTH-1:0] y);
             
  assign y = a + b;
endmodule

//```````````````````````````````````````````````````````````````
module flopenr #(parameter WIDTH = 8)
                (input  logic             clk, reset, en,
                 input  logic [WIDTH-1:0] d, 
                 output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset)   q <= 0;
    else if (en) q <= d;
endmodule

//```````````````````````````````````````````````````````````````
module flopr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

//```````````````````````````````````````````````````````````````
module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule


//ALU MODULE FROM LAB 1
module alu(input logic [31:0] a, b, 
    input logic [2:0] ALUControl,
    output logic [31:0] Result,
    output logic [3:0] ALUFlags);
      
      
logic[31:0] Cout;
logic[31:0] res;
reg [31:0] results;
reg [3:0] flags;
reg [31:0] altB;

always_comb begin
  for (int i = 0; i < 32; i=i+1) altB[i] = b[i] ^ ALUControl[0];
end

EightBitAdder bits0_7(.A(a[7:0]), .B(altB[7:0]), .Cin(ALUControl[0]), .S(res[7:0]), .Cout(Cout[7:0]));
EightBitAdder bits8_15(.A(a[15:8]), .B(altB[15:8]), .Cin(Cout[7]), .S(res[15:8]), .Cout(Cout[15:8]));
EightBitAdder bits16_23(.A(a[23:16]), .B(altB[23:16]), .Cin(Cout[15]), .S(res[23:16]), .Cout(Cout[23:16]));
EightBitAdder bits24_31(.A(a[31:24]), .B(altB[31:24]), .Cin(Cout[23]), .S(res[31:24]), .Cout(Cout[31:24]));

always_comb begin
  for (integer i = 0; i < 4; i=i+1) begin
    {flags[i]} = 0;
  end
  results = res;
  
    flags[2] = 1;
     for (integer i = 0; i < 32; i=i+1) begin
  	     if (b[i] == 1) flags[2] = 0;
  	  end
  	  if (flags[2] == 1 && ALUControl[0] == 1 && ALUControl[1] == 0 && ALUControl[2] == 1) flags[1] = 1;
  	    
  if (ALUControl[1] == 0) begin
    if (Cout[31] ^ Cout[30] == 1) begin
      {flags[0]} = 1;
    end
    if (flags[1] == 0) flags[1] = Cout[31];
  end
  if (ALUControl[1] == 1) begin
    if (ALUControl[0] == 0) begin
  	   results = a & b;
    end
    if (ALUControl[0] == 1) begin
     	results = a | b;
    end
  end
  if (ALUControl[2] == 0) begin
    if (ALUControl[0] == 0) begin
      results = a ^ b;
    end
  end
  flags[2] = 1;
  for (integer i = 0; i < 32; i=i+1) begin
    if (results[i] == 1) flags[2] = 0;
  end
  if (results[31] == 1) begin
    flags[3] = 1;
  end
end

assign ALUFlags = flags;
assign Result = results;

endmodule


module EightBitAdder(
    input logic [7:0] A,
    input logic [7:0] B,
    input logic Cin,
    output logic [7:0] S,
    output logic [7:0] Cout
);

OneBitAdder bit0(.A(A[0]), .B(B[0]), .Cin(Cin), .S(S[0]), .Cout(Cout[0]));
OneBitAdder bit1(.A(A[1]), .B(B[1]), .Cin(Cout[0]), .S(S[1]), .Cout(Cout[1]));
OneBitAdder bit2(.A(A[2]), .B(B[2]), .Cin(Cout[1]), .S(S[2]), .Cout(Cout[2]));
OneBitAdder bit3(.A(A[3]), .B(B[3]), .Cin(Cout[2]), .S(S[3]), .Cout(Cout[3]));
OneBitAdder bit4(.A(A[4]), .B(B[4]), .Cin(Cout[3]), .S(S[4]), .Cout(Cout[4]));
OneBitAdder bit5(.A(A[5]), .B(B[5]), .Cin(Cout[4]), .S(S[5]), .Cout(Cout[5]));
OneBitAdder bit6(.A(A[6]), .B(B[6]), .Cin(Cout[5]), .S(S[6]), .Cout(Cout[6]));
OneBitAdder bit7(.A(A[7]), .B(B[7]), .Cin(Cout[6]), .S(S[7]), .Cout(Cout[7]));

endmodule


module OneBitAdder(
  input logic A,
  input logic B,
  input logic Cin,
  output logic S,
  output logic Cout);
  
logic	WIRE_1;
logic	WIRE_2;
logic	WIRE_3;
  
assign WIRE_1 = A ^ B;
assign S = WIRE_1 ^ Cin;
assign WIRE_2 = WIRE_1 & Cin;
assign WIRE_3 = A & B;
assign Cout = WIRE_2 | WIRE_3;

endmodule