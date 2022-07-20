![](https://cdn.nlark.com/yuque/0/2022/jpeg/22909236/1657111390027-9c0a0b75-7325-4d34-9a53-077568b242f5.jpeg?x-oss-process=image%2Fresize%2Cw_1536%2Climit_0)
分支预测：
方向预测：BHR+PHT
目标地址预测：call return，BTB
PHT：2KB（可使用hash）
分支预测失败在何时检出？X阶段

双发射：
普通指令，一个pc，进入icache，下一次是pc+8，
i cache data一次两条，两个解码单元。

分支预测的结果是两条，通往哪里？解析直接放在fetch1？

pc的来源：

面向测试：如何通过？
在fetch2阶段获得两条指令，不使用cacahe的话，要通过测试，需要额外等待两次设定为全流水线阻塞。阻塞沿用之前的逻辑。

先完成lab1的指令。将未出现的异常和中断信号置0。将多余的信号删除。

j指令，如何识别出是j指令？至少在fetch2阶段。
j
jal
jr
weekly not taken
如何写一个假的分支预测？
一直预测not teken，然后发现后全部flush

在没有cache的情况下，就是等待两次，这里我手动输入两次addr。

跳转指令：虽然不懂在fetch1阶段可不可以但先这么写吧

j指令无预测，flush两条在F1的指令。
需要注意是延迟槽中的pc前4位
注意位宽！
取出两条的话
1. 第一条是j指令，第二条是延迟槽，
2. 第二条是j指令，下一流水段只flush一条
对于跳转的影响：好像没有

