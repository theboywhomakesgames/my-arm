`ifndef ARM
`define ARM
`include "clockgenerator.v"
`include "registerbank.v"
`include "addressregister.v"
`include "barrelshifter.v"
`include "multiplier.v"
`include "rpadder32.v"
`include "decoder.v"
`include "ALU.v"

module whole;
	// =========
	// Variables
	// =========
	reg[31:0] reg_write,
		pc_write,
		alubus,
		busA,
		busB,
		data_read,
		data_write,
		instruction,
		cpsr_write,
		cpsr_mask;
	reg [31:0] one = 32'hffffffff;
	reg [31:0] zero = 0; 
	reg[4:0] address1, address2;
	reg reg_w, pc_w, ale, abe, w, cpsr_w;
	reg t_clk1, t_clk2;
	reg[31:0] mult_input_1;
	reg[7:0] mult_input_2;
	reg[2:0] shifter_mode;
	reg[4:0] shifter_count;
	reg alu_active;
	reg[31:0] instructions[31:0]; // 32 test instructions

	wire clk1, clk2;
	wire[31:0] read1, read2, pc_read, incrementerbus, ar;
	wire[31:0] mult_output;
	wire[31:0] shifter_output;
	wire do_reg_w, do_pc_w, do_ale, do_abe, is_immediate, do_immediate_shift, do_S, do_aluhot;
	wire[2:0] do_shifter_mode;
	wire[4:0] do_shifter_count;
	wire[3:0] do_Rn, do_Rd, do_Rm, do_Rs;
	wire alu_invert_a, alu_invert_b, alu_is_logic, alu_cin;
	wire[2:0] alu_logic_idx;
	wire[31:0] alu_result;
	wire alu_N, alu_Z, alu_C, alu_V;

	// =============
	// Modules Instantiation
	// =============
	// clock
	clock clkmodule(clk1, clk2);

	// register bank
	registerbank rbmodule(
		reg_write,
		pc_write,
		cpsr_write,
		cpsr_mask,
		address1,
		address2,
		reg_w,
		pc_w,
		cpsr_w,
		t_clk1,
		t_clk2,
		read1,
		read2,
		pc_read
	);

	// address register + incrementer
	addressregister armodule(
		t_clk2, // ?
		ale,
		abe,
		alubus,
		incrementerbus,
		ar
	);

	// multiplier
	multiplier multipliermodule(mult_input_1, mult_input_2, mult_output);

	// barrelshifter
	barrelshifter shiftermodule(busB, shifter_mode, shifter_count, shifter_output);

	// decoder - do means decoder output
	decoder decodermodule(
		instruction,
		t_clk1,
		do_reg_w,
		do_pc_w,
		do_ale,
		do_abe,
		is_immediate,
		do_S,
		do_aluhot,
		do_shifter_mode,
		alu_logic_idx,
		do_shifter_count,
		do_Rn,
		do_Rd,
		do_Rm,
		do_Rs,
		alu_invert_a,
		alu_invert_b,
		alu_is_logic,
		alu_cin,
		do_immediate_shift
	);

	ALU alumodule(
		busA,
		shifter_output,
		alu_invert_a,
		alu_invert_b,
		alu_is_logic,
		alu_logic_idx,
		alu_cin,
		alu_active,
		alu_result,
		alu_N,
		alu_Z,
		alu_C,
		alu_V
	);

	initial begin
		// fill in reg[0]
		address1 = 0;
		reg_write = 32'hfffffff0;
		reg_w = 1;
		t_clk2 = 1;
		#10 t_clk2 = 0;

		// fill in reg[1]
		address1 = 1;
		reg_write = 32'h0000000f;
		reg_w = 1;
		t_clk2 = 1;
		#10 t_clk2 = 0;
		reg_w = 0;

		// Data Processing operand2 addressing types
		// immediate addressing
		instructions[0][31:28] = 0; // condition
		instructions[0][27:26] = 0; // instruction group
		instructions[0][25] = 1; // #
		instructions[0][24:21] = 4'b0100; // opcode: add
		instructions[0][20] = 1; // S
		instructions[0][19:16] = 0; // first operand reg
		instructions[0][15:12] = 0; // destination reg
		instructions[0][11:8] = 0; // #rot
		instructions[0][7:0] = 8'h0f; // immediate

		// reg addressing with immediate shift
		instructions[1][31:28] = 0; // condition
		instructions[1][27:26] = 0; // instruction group
		instructions[1][25] = 0; // #
		instructions[1][24:21] = 4'b0100; // opcode: add
		instructions[1][20] = 1; // S
		instructions[1][19:16] = 0; // first operand reg
		instructions[1][15:12] = 0; // destination reg
		instructions[1][11:7] = 0; // immediate shift length
		instructions[1][6:5] = 0; // shift type
		instructions[1][4] = 0; // immediate shift
		instructions[1][3:0] = 1; // Rm

		// reg addressing with reg shift
		instructions[2][31:28] = 0; // condition
		instructions[2][27:26] = 0; // instruction group
		instructions[2][25] = 0; // #
		instructions[2][24:21] = 4'b0000; // opcode: add
		instructions[2][20] = 1; // S
		instructions[2][19:16] = 0; // first operand reg
		instructions[2][15:12] = 0; // destination reg
		instructions[2][11:8] = 2; // Rs
		instructions[2][7] = 0; // just for alignment
		instructions[2][6:5] = 0; // shift type
		instructions[2][4] = 1; // immediate shift
		instructions[2][3:0] = 1; // Rm

		// fetch
		instruction = instructions[2];
		reg_w = 0;

		// decode
		$display("decode");
		t_clk1 = 1;

		// operand fill
		#10 if(is_immediate) begin
			address1 = do_Rn;

			#10 t_clk1 = 0;
			busA = read1;

			// calculate operand 2
			busB = instruction[7:0];
			shifter_count = do_shifter_count;
			shifter_mode = do_shifter_mode;
			#5 $display("immedate addressing %h", shifter_output);
		end
		else begin
			address1 = do_Rn;
			address2 = do_Rm;

			t_clk1 = 1;
			#5 t_clk1 = 0;
			busA = read1;
			busB = read2;

			// shift
			if(do_immediate_shift) begin
				shifter_count = do_shifter_count;
			end
			else begin
				// bypass -- I don't want a double clock instruction
				shifter_count = 0;
			end
			shifter_mode = do_shifter_mode;
			#5 $display("shifter output %h", shifter_output);
		end

		if(do_aluhot) begin
			// alu hot spot
			alu_active = 1;
			#36 $display("alu inputs busA : %h busB: %h, output: %h", busA, shifter_output, alu_result);
			alu_active = 0;
			reg_write = alu_result;
		end
		else begin
			reg_write = shifter_output;
		end

		// write to register bank
		if(do_reg_w) begin
			if(is_immediate == 1) begin
				address1 = do_Rd;
				reg_w = 1;
				t_clk2 = 1;
				#10 t_clk2 = 0;
			end
			else begin
				address1 = do_Rd;
				reg_w = 1;
			end

			// Set conditions
			if(do_S) begin
				cpsr_write =  {alu_N, alu_Z, alu_C, alu_V, zero[27:0]};
				cpsr_mask = one;
				cpsr_w = 1;
			end

			t_clk2 = 1;
			#10 t_clk2 = 0;

			$finish();
		end
	end
endmodule
`endif