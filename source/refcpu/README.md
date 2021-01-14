`RefCPU` is intended to be a behavioral model of our MIPS CPU. It is a multi-cycle CPU and thus it's expected to be easier to extend and debug than a pipeline CPU. DO NOT try to synthesize `RefCPU` since it uses a big global `ctx` register between states...

TODO:

* [ ] demo instruction: `ADD`
* [ ] demo instruction: `ADDI`
* [ ] demo instruction: `BNE`
* [ ] delay slot
* [ ] `NaiveBuffer`
