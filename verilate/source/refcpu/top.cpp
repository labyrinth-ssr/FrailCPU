#include "refcpu/top.h"
#include "verilated_fst_c.h"

constexpr int MAX_FST_TRACE_DEPTH = 32;

RefCPU::RefCPU()
    : tfp(nullptr), text_tfp(nullptr),
      current_num(0), fst_trace_count(0),
      test_finished(false) {}

RefCPU::~RefCPU() {
    if (tfp)
        stop_fst_trace();
    if (text_tfp)
        stop_text_trace();
    if (diff.is_open())
        close_reference_trace();
}

void RefCPU::install_memory(const std::shared_ptr<BlockMemory> &mem) {
    con = std::make_shared<Confreg>();
    std::vector<MemoryRouter::Entry> layout = {
        {0xfff00000, 0x1fc00000, mem, [](addr_t addr) { return addr - 0x1fc00000; }},
        {0xffff0000, 0x1faf0000, con, identity_fn<addr_t>},
        {0x00000000, 0x00000000, mem, identity_fn<addr_t>},
    };
    auto router = std::make_shared<MemoryRouter>(layout);
    dev = std::make_shared<CBusDevice>(router);
}

void RefCPU::start_fst_trace(const std::string &path) {
    assert(!tfp);

    tfp = new VerilatedFstC;
    fst_trace_count = 0;
    trace(tfp, MAX_FST_TRACE_DEPTH);
    tfp->open(path.data());

    fst_trace_dump(+0);
}

void RefCPU::stop_fst_trace() {
    assert(tfp);

    notify("trace: stop @%d\n", time());
    eval();
    tfp->dump(time() + 10);

    tfp->flush();
    tfp->close();
    tfp = nullptr;
}

void RefCPU::fst_trace_dump(uint64_t t) {
    if (tfp)
        tfp->dump(time() + t);
}

void RefCPU::start_text_trace(const std::string &path) {
    assert(!text_tfp);
    text_tfp = fopen(path.data(), "w");
}

void RefCPU::stop_text_trace() {
    assert(text_tfp);
    fclose(text_tfp);
    text_tfp = nullptr;
}

void RefCPU::text_trace_dump(addr_t pc, RegisterID id, word_t value) {
    char buf[64];
    sprintf(buf, "%01x %08x %02x %08x", con->trace_enabled(), pc, id, value);

    if (text_tfp)
        fprintf(text_tfp, "%s\n", buf);

    diff.check_line(buf, con->trace_enabled());
}

void RefCPU::open_reference_trace(const std::string &path) {
    diff.open(path);
}

void RefCPU::close_reference_trace() {
    diff.close();
}

void RefCPU::tick(int count) {
    while (count--) {
        _tick();
    }
}
