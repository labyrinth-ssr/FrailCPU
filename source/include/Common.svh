/**
 * this file contains basic definitions and typedefs for all designs.
 */

`ifndef __COMMON_SVH__
`define __COMMON_SVH__

typedef int unsigned uint;

typedef logic [3 :0] i4;
typedef logic [7 :0] i8;
typedef logic [15:0] i16;
typedef logic [31:0] i32;
typedef logic [63:0] i64;

// all addresses and words are 32-bit
typedef i32 addr_t;
typedef i32 word_t;

// view a word as 4 bytes
typedef union packed {
    word_t word;
    i8 [3:0] bytes;
} view_t;

// a 4-bit mask, namely "write enable"
typedef i4 wrten_t;

// general-purpose registers
typedef enum logic [4:0] {
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
 */

/**
 * data cache bus
 *
 * basically, dbus_resp_t is as same as ibus_resp_t.
 */

typedef struct packed {
    logic   valid;     // in request?
    addr_t  addr;      // target address
    wrten_t write_en;  // which bytes are enabled? set to zeros for read request
    view_t  data;      // the data to write
} dbus_req_t;

typedef struct packed {
    logic  addr_ok;  // is the address accepted by cache?
    logic  data_ok;  // is the field "data" valid?
    view_t data;     // the data read from cache
} dbus_resp_t;

/**
 * instruction cache bus
 */

typedef struct packed {
    logic  valid;  // in request?
    addr_t addr;   // target address
} ibus_req_t;

typedef dbus_resp_t ibus_resp_t;

/**
 * cache bus: simplified burst AXI transaction
 */

parameter int CBUS_LEN_BITS   = 16;
parameter int CBUS_LEN_MAX    = 2**(CBUS_LEN_BITS - 1);  // 2^15 = 32768
parameter int CBUS_ORDER_BITS = $clog2(CBUS_LEN_BITS);   // 4

typedef struct packed {
    logic  valid;     // in request?
    logic  is_write;  // is it a write transaction?
    i4     order;     // the length of transaction, given by 2^order
    addr_t addr;      // start address of the transaction
    view_t data;      // the data to write
} cbus_req_t;

typedef struct packed {
    logic  ready;  // is data arrived in this cycle?
    logic  last;   // is it the last word?
    view_t data;   // the data from AXI bus
} cbus_resp_t;

`endif
