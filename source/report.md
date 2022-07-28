异常与中断：

- 异常：
flush流水线：在M1阶段flush一次（防止异常到达w阶段时有不该执行的指令访存），writeback阶段再flush一次。
