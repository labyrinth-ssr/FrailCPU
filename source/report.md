异常与中断：

- 异常：
flush流水线：在M1阶段flush一次（防止异常到达w阶段时有不该执行的指令访存），writeback阶段再flush一次。
取消overflow：branchM和中断。
中断打断ireq：

双端口regfile，写同一地址。
中间残留了branch没有flush，应当被flush。
异常出现后要记录出现的pc，
中断不会打断i_wait

dwait期间，不会出现异常。也没有中断（因为中断只有在pc[1]有效时出现。）

branchM在[1],就valid=0，在[0]。