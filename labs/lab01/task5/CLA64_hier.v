// cla64_hier.v
// BONUS -- open-ended. No detailed scaffold is provided; this is meant to
// be a genuine design exercise. Not required for lab submission.
//
// You will likely need to modify cla4.v (or add signals alongside it) so
// that block-generate/block-propagate summaries of its own Gi, Pi signals
// are exposed as outputs, since the second-level lookahead unit below
// needs them. As with every module in this lab from Task 2 onward, every
// gate/assign you add should carry an explicit delay.
//
// Starting point (from Tutorial 3, Q4(d)):
//   - Reuse 16 four-bit CLA blocks (your cla4.v) -- their internal logic
//     doesn't change.
//   - For each block k, define:
//       Gblk_k = "this block produces a carry regardless of its incoming
//                 carry" -- a Boolean function of that block's own 4
//                 bit-level Gi, Pi signals.
//       Pblk_k = "an incoming carry sails straight through this whole
//                 block" -- likewise a function of its own Gi, Pi.
//   - Build a second-level lookahead unit -- structurally identical to
//     cla4.v, just one level up -- that computes each block's carry-in
//     directly from Gblk_0..Gblk_15, Pblk_0..Pblk_15, and cin, instead of
//     rippling block to block.
//
// To test this, wire it into dut.v as a fourth option (copy the pattern
// used for the other three) and run it through the same tb.v. Compare
// your final delay to cla64_blocked.v from Task 4.

// cla64_hier.v
// 64-bit Hierarchical Carry-Lookahead Adder (3-level tree)

// cla64_hier.v - Fully Hierarchical 64-bit CLA (14 ns Delay)

module cla64_hier(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  wire [15:0] g_blk, p_blk;
  wire [15:0] c_in_blk;

  wire [3:0] g_super, p_super;
  wire [3:1] c_super;
  wire [3:0] group_cin;

  // Level 3: Top-level carry inputs
  assign group_cin[0]   = cin;
  assign group_cin[3:1] = c_super[3:1];

  // Level 3 LCU (16-bit Super Blocks)
  lcu4 top_lcu (
    .g(g_super),
    .p(p_super),
    .cin(cin),
    .c(c_super),
    .cout(cout),
    .g_super(),
    .p_super()
  );

  // Level 2 LCUs (4-bit Leaf Blocks)
  genvar s;
  generate
    for (s = 0; s < 4; s = s + 1) begin : gen_mid_lcu
      lcu4 mid_lcu (
        .g(g_blk[s*4 +: 4]),
        .p(p_blk[s*4 +: 4]),
        .cin(group_cin[s]),
        .c(c_in_blk[s*4+1 +: 3]),
        .cout(),
        .g_super(g_super[s]),
        .p_super(p_super[s])
      );
      assign c_in_blk[s*4] = group_cin[s];
    end
  endgenerate

  // Level 1: Leaf 4-bit CLA blocks
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_leaf_cla
      cla4_hp block (
        .a(a[i*4 +: 4]),
        .b(b[i*4 +: 4]),
        .cin(c_in_blk[i]),
        .sum(sum[i*4 +: 4]),
        .cout(),
        .g_blk(g_blk[i]),
        .p_blk(p_blk[i])
      );
    end
  endgenerate

endmodule


module cla4_hp(
  input  [3:0] a,
  input  [3:0] b,
  input        cin,
  output [3:0] sum,
  output       cout,
  output       g_blk,
  output       p_blk
);

  wire [3:0] p, g;
  wire [3:1] c;

  // Bit propagate and generate (Delay = 2ns)
  assign #(2) p = a ^ b;
  assign #(2) g = a & b;

  // Internal carry generation (Delay = 2ns after g/p ready)
  assign #(2) c[1] = g[0] | (p[0] & cin);
  assign #(2) c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
  assign #(2) c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);
  assign #(2) cout = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & cin);

  // Block terms passed up to mid-level LCU (Delay = 2ns)
  assign #(2) p_blk = p[3] & p[2] & p[1] & p[0];
  assign #(2) g_blk = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);

  // Sum generation
  assign #(2) sum[0] = p[0] ^ cin;
  assign #(2) sum[1] = p[1] ^ c[1];
  assign #(2) sum[2] = p[2] ^ c[2];
  assign #(2) sum[3] = p[3] ^ c[3];

endmodule


module lcu4(
  input  [3:0] g,
  input  [3:0] p,
  input        cin,
  output [3:1] c,
  output       cout,
  output       g_super,
  output       p_super
);

  assign #(2) c[1]    = g[0] | (p[0] & cin);
  assign #(2) c[2]    = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
  assign #(2) c[3]    = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);
  assign #(2) cout   = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & cin);

  assign #(2) p_super = p[3] & p[2] & p[1] & p[0];
  assign #(2) g_super = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);

endmodule