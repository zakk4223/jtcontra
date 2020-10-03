/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 3-10-2020 */

module jtlabrun_game(
    input           rst,
    input           clk,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [4:0]  red,
    output   [4:0]  green,
    output   [4:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en
);

// SDRAM offsets.
localparam GFX_OFFSET =  22'h2_0000>>1;
localparam PROM_START  =  22'h6_0000;

wire        main_cs, main_ok, gfx_ok;
wire        pcm_cs,  pcm_ok;
wire        snd_irq;
wire [15:0] gfx_data, gfx2_data;
wire [ 7:0] pcm_data;
wire [16:0] pcm_addr;
wire [17:0] gfx_addr, gfx2_addr;

wire [ 7:0] main_data, snd_data, snd_latch;
wire [14:0] snd_addr;
wire [17:0] main_addr;
wire        cen12, cen3, cen1p5, prom_we;
wire        gfx_cs, gfx2_cs;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
wire        LHBL, LVBL;

wire [15:0] cpu_addr;
wire        gfx_irqn, gfx_romcs, gfx2_romcs, gfx_cfg_cs, gfx2_cfg_cs, pal_cs;
wire        gfx_vram_cs, gfx2_vram_cs;
wire        cpu_cen, cpu_rnw, cpu_irqn;
wire [ 7:0] gfx_dout, gfx2_dout, pal_dout, cpu_dout;
wire [ 7:0] video_bank;
wire        prio_latch;

assign prog_rd    = 0;
assign dwnld_busy = downloading;
assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];


jtframe_cen24 u_cen(
    .clk        ( clk24         ),    // 24 MHz
    .cen12      ( cen12         ),
    .cen6       (               ),
    .cen4       (               ),
    .cen3       ( cen3          ),
    .cen3q      (               ), // 1/4 advanced with respect to cen3
    .cen1p5     ( cen1p5        ),
    // 180 shifted signals
    .cen12b     (               ),
    .cen6b      (               ),
    .cen3b      (               ),
    .cen3qb     (               ),
    .cen1p5b    (               )
);

jtframe_dwnld #(.PROM_START(PROM_START))
u_dwnld(
    .clk            ( clk           ),
    .downloading    ( downloading   ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_data     ( ioctl_data    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prom_we        ( prom_we       ),
    .sdram_ack      ( sdram_ack     )
);

`ifdef GFX_ONLY
jtcontra_simloader u_simloader(
    .rst        ( rst           ),
    .clk        ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    // GFX
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),
    .gfx_cs    ( gfx_cs       ),
    .gfx2_cs    ( gfx2_cs       ),
    .pal_cs     ( pal_cs        ),
    .video_bank ( video_bank    ),
    .prio_latch ( prio_latch    )
);
`else
`ifndef NOMAIN
jtcontra_main #(.GAME(GAME)) u_main(
    .clk            ( clk24         ),        // 24 MHz
    .rst            ( rst           ),
    .cen12          ( cen12         ),
    .cpu_cen        ( cpu_cen       ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( 1'b1          ),
    // GFX
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_cs        ( gfx_cs       ),
    .gfx2_cs        ( gfx2_cs       ),
    .pal_cs         ( pal_cs        ),

    .gfx_dout      ( gfx_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),

    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       )
);
`else
// load a sound code for simulation
assign snd_latch = 8'h22;
reg pre_irq=0;
initial begin
    #100_000_000 pre_irq=1;
end

assign snd_irq = pre_irq;
`endif
`endif

`ifndef NOVIDEO
jtcontra_video #(.GAME(GAME)) u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk24          ( clk24         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .LHBL_dly       ( LHBL_dly      ),
    .LVBL_dly       ( LVBL_dly      ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( dip_flip      ),
    .dip_pause      ( dip_pause     ),
    .start_button   ( &start_button ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[9:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .cpu_irqn       ( cpu_irqn      ),
    .gfx_cs        ( gfx_cs       ),
    .gfx2_cs        ( gfx2_cs       ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_cen        ( cpu_cen       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .gfx_dout      ( gfx_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),
    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // SDRAM
    .gfx_addr      ( gfx_addr     ),
    .gfx_data      ( gfx_data     ),
    .gfx_ok        ( gfx_ok       ),
    .gfx_romcs     ( gfx_romcs    ),
    .gfx2_addr      ( gfx2_addr     ),
    .gfx2_data      ( gfx2_data     ),
    .gfx2_ok        ( gfx2_ok       ),
    .gfx2_romcs     ( gfx2_romcs    ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        )
);
`endif

jtframe_rom #(
    .SLOT0_AW    ( 18              ),
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( GFX_OFFSET      ),

    .SLOT7_AW    ( 18              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              )  // Main
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .vblank      ( ~LVBL         ),

    .slot0_cs    ( gfx_romcs     ),
    .slot1_cs    ( 1'b0          ),
    .slot2_cs    ( 1'b0          ),
    .slot3_cs    ( 1'b0          ), // unused
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( 1'b0          ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b0          ),

    .slot0_ok    ( gfx_ok        ),
    .slot1_ok    (               ),
    .slot2_ok    (               ),
    .slot3_ok    (               ),
    .slot4_ok    (               ),
    .slot5_ok    (               ),
    .slot6_ok    (               ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    (               ),

    .slot0_addr  ( gfx_addr      ),
    .slot1_addr  (               ),
    .slot2_addr  (               ),
    .slot3_addr  (               ),
    .slot4_addr  (               ),
    .slot5_addr  (               ),
    .slot6_addr  (               ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  (               ),

    .slot0_dout  ( gfx_data      ),
    .slot1_dout  (               ),
    .slot2_dout  (               ),
    .slot3_dout  (               ),
    .slot4_dout  (               ),
    .slot5_dout  (               ),
    .slot6_dout  (               ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  (               ),

    .ready       (               ),
    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .refresh_en  ( refresh_en    )
);

endmodule