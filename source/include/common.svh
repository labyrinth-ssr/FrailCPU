/**
 * this file contains basic definitions and typedefs for general designs.
 */

`ifndef __COMMON_SVH__
`define __COMMON_SVH__

`define BITS(x) logic[(x)-1:0]

package common;

typedef int unsigned uint;

typedef `BITS(2)  i2;
typedef `BITS(3)  i3;
typedef `BITS(4)  i4;
typedef `BITS(5)  i5;
typedef `BITS(6)  i6;
typedef `BITS(7)  i7;
typedef `BITS(8)  i8;
typedef `BITS(16) i16;
typedef `BITS(32) i32;
typedef `BITS(64) i64;

// all addresses and words are 32-bit
typedef i32 addr_t;
typedef i32 word_t;

// view a word as 4 bytes
typedef union packed {
    word_t word;
    i8 [3:0] bytes;
} view_t;

// number of bytes transferred in one memory r/w
typedef enum i3 {
    MSIZE1,
    MSIZE2,
    MSIZE4
} msize_t;

// length of a burst transaction
// NOTE: WRAP mode in AXI3 only supports power-of-2 length.
typedef enum i4 {
    MLEN1  = 4'b0000,
    MLEN2  = 4'b0001,
    MLEN4  = 4'b0011,
    MLEN8  = 4'b0111,
    MLEN16 = 4'b1111
} mlen_t;

// a 4-bit mask for memory r/w, namely "write enable"
typedef i4 strobe_t;

// general-purpose registers
typedef enum i5 {
    R0, AT, V0, V1, A0, A1, A2, A3,
    T0, T1, T2, T3, T4, T5, T6, T7,
    S0, S1, S2, S3, S4, S5, S6, S7,
    T8, T9, K0, K1, GP, SP, FP, RA
} regid_t;

/**
 * SOME NOTES ON BUSES
 *
 * bus naming convention:
 *  * CPU -> cache: xxx_req_t
 *  * cache -> CPU: xxx_resp_t
 *
 * in other words, caches are masters and CPU is the worker,
 * and CPU must wait for caches to complete memory transactions.
 * handshake signals are synchronized at positive edge of the clock.
 *
 * we guarantee that IBus is a subset of DBus, so that data cache can
 * be used as a instruction cache.
 * powerful students are free to design their own bus interfaces to
 * enable superscalar pipelines and other advanced techniques.
 *
 * a request on cache bus can bypass a cache instance if the address
 * is in uncached memory regions.
 */

/**
 * data cache bus
 */

typedef struct packed {
    logic    valid;   // in request?
    msize_t  size;    // number of bytes
    addr_t   addr;    // target address
    strobe_t strobe;  // which bytes are enabled? set to zeros for read request
    view_t   data;    // the data to write
} dbus_req_t;

typedef struct packed {
    logic  addr_ok;  // is the address accepted by cache?
    logic  data_ok;  // is the field "data" valid?
    view_t data;     // the data read from cache
} dbus_resp_t;

/**
 * instruction cache bus
 *
 * basically, ibus_resp_t is the same as dbus_resp_t.
 */

typedef struct packed {
    logic   valid;  // in request?
    msize_t size;   // number of bytes
    addr_t  addr;   // target address
} ibus_req_t;

typedef dbus_resp_t ibus_resp_t;

/**
 * cache bus: simplified burst AXI transaction interface
 */

typedef struct packed {
    logic    valid;     // in request?
    logic    is_write;  // is it a write transaction?
    msize_t  size;      // number of bytes in one burst
    addr_t   addr;      // start address
    strobe_t strobe;    // which bytes are enabled?
    view_t   data;      // the data to write
    mlen_t   len;       // number of bursts
} cbus_req_t;

typedef struct packed {
    logic  ready;  // is data arrived in this cycle?
    logic  last;   // is it the last word?
    view_t data;   // the data from AXI bus
} cbus_resp_t;

/**
 * AXI-related typedefs
 */

typedef enum i2 {
    AXI_BURST_FIXED,
    AXI_BURST_INCR,
    AXI_BURST_WRAP,
    AXI_BURST_RESERVED
} axi_burst_type_t;

endpackage

`endif
