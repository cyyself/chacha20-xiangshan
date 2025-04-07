# 香山处理器上的 ChaCha20 加密算法优化

## 问题描述

ChaCha20 是一种流密码算法，用于生成伪随机数流。是我们日常访问 https 网页常用的 TLS 协议中的流加密算法之一。ChaCha20 算法的设计目标是在硬件不支持如 AES 等加密算法的情况下，提供一种高效且安全的软件加密算法。

ChaCha20 算法的核心是一个 4x4 的矩阵，矩阵中的元素是 32 位无符号整数。ChaCha20 算法的输入包括一个 256 位的密钥、一个 64 位的计数器和一个 64 位的随机数， **在我们的程序中通过 16 个 32 位无符号数组 state 表示** 。ChaCha20 算法的输出是一个伪随机数流，将欲加密的数据与伪随机数流进行异或运算，即可得到加密后的数据。

我们在该仓库中提供了 OpenSSL 的 Chacha20 加密算法的 C 语言参考实现，您可以在 `src/host/chacha20_c.c` 文件中找到该实现。我们希望您能够在香山处理器上对该算法进行优化，算法按照以下格式定义：

```c
typedef union {
    u32 u[16];
    u8 c[64];
} chacha_buf;

void chacha20(chacha_buf *output, const u32 input[16]);
```

修改`src/asm/chacha20.s`文件，使得该算法在香山处理器上能更快速地运行。

目前该 baseline 是在使用 `GCC 14.2`，使用命令 `riscv64-linux-gnu-gcc -O3 -march=rv64gc -Isrc -S -fverbose-asm src/host/chacha20_c.c` 下生成的。

## 框架使用

### 环境准备

针对 x86-64 的 Debian / Ubuntu 系统，您可以使用以下命令安装必要的依赖：

```bash
sudo apt install make wget gcc gcc-riscv64-linux-gnu qemu-user
```

香山 emu 我们已经基于 [commit 1f23fd0f52e1d022ef0a6c2a206d3733263bac23](https://github.com/OpenXiangShan/XiangShan/tree/1f23fd0f52e1d022ef0a6c2a206d3733263bac23) 预编译为静态链接的 x86-64 Linux 的二进制文件，在 Makefile 中已经配置好了可以从网络下载的 url 。

针对其他平台的选手，可以自行按照该 commit 编译香山 emu，或自行配置 qemu-user、Rosetta 等二进制转换工具，如果实在有困难可以联系我们提供 x86-64 云服务器。

### Makefile

可选参数：

- `BENCH_LEN`: 用于测试的数组长度

目标命令：

- `make validate`: 验证优化后的算法在 QEMU 上是否正确
- `make run`: 在 香山模拟器上运行优化后的算法，查看性能指标
- `make validate-rtl`: 验证优化后的算法在香山模拟器上是否正确
- `make clean`: 清理编译产物

### 性能验证

对于小数据验证，可以使用 `make run` 命令，该命令会在香山处理器上运行优化后的算法，并输出性能指标。

```console
$ make run
./xs-emu -i ./chacha20_baremetal-256.bin --no-diff 2>/dev/null
xs-emu compiled at Mar 28 2025, 11:26:20
Using simulated 32768B flash
Using simulated 8386560MB RAM
The image is ./chacha20_baremetal-256.bin
Test Start!
Initial state generated for LEN=256 SEED=0xdeadbeef
Cycles: 143409
Final output: 
ans[0] = 0xbe64d5a5
ans[1] = 0x83c6c3fa
ans[2] = 0xac710378
ans[3] = 0x858f0082
ans[4] = 0x207f2dc2
ans[5] = 0xeb5ee49e
ans[6] = 0x4f801257
ans[7] = 0x2e4f03c9
ans[8] = 0x74b07deb
ans[9] = 0x3e6dde54
ans[10] = 0x6dd3ddad
ans[11] = 0xee18cf6c
ans[12] = 0x053765e6
ans[13] = 0x79f814eb
ans[14] = 0x40b18db8
ans[15] = 0xa299c057
Core 0: HIT GOOD TRAP at pc = 0x80010002
Core-0 instrCnt = 452,265, cycleCnt = 171,941, IPC = 2.630350
Seed=0 Guest cycle spent: 171,945 (this will be different from cycleCnt if emu loads a snapshot)
Host time spent: 16,376ms
```

其中，我们观测到 `Cycles: 143409` ，表示该大小的数据处理时间为 `143409` 个时钟周期。该数值越小则性能越好。

## 评价标准

评分时采用数据大小：`BENCH_LEN=4096`

基本要求：
- 优化后的算法在香山处理器 RTL 模拟器上能够正确运行
    即：通过 `make validate-rtl BENCH_LEN=4096`

性能要求：
对于参赛者按照优化后的算法在香山处理器的 RTL 模拟器上运行的时钟周期数进行排名，使用命令 `make run BENCH_LEN=4096` 获得时钟周期数对参赛者的提交进行排名，周期数越小，排名越靠前。

## 规则

提交的代码为 `src/chacha20.s` 修改后的版本，如果发现了有必要使用新的扩展指令，且该扩展已经在该版本的香山 RTL 中实现，可以修改 Makefile 中的 `-march` 参数。若有修改 CSR 寄存器的需求，也可以修改整个框架，但需要在文档中说明。

允许选手提交自己优化编译器的自动向量化生成的代码，或基于已有开源实现的基础上进行进一步优化，但需要附上详细的说明文档说明参考算法的来源，编译器以及参数的改动，优化前后的对比。

禁止选手的代码出现了任何失去了算法通用性的优化，包括但不限于：
- 设计上无法支持所有的 state 输入
- 直接输出固定的结果

## 赛题解析

### Chacha20 算法与 RISC-V 指令集

我们首先观察最简单的 C 语言实现的 Chacha20 算法：

```c
# define ROTATE(v, n) (((v) << (n)) | ((v) >> (32 - (n))))

/* QUARTERROUND updates a, b, c, d with a ChaCha "quarter" round. */
# define QUARTERROUND(a,b,c,d) ( \
x[a] += x[b], x[d] = ROTATE((x[d] ^ x[a]),16), \
x[c] += x[d], x[b] = ROTATE((x[b] ^ x[c]),12), \
x[a] += x[b], x[d] = ROTATE((x[d] ^ x[a]), 8), \
x[c] += x[d], x[b] = ROTATE((x[b] ^ x[c]), 7)  )

/* chacha_core performs 20 rounds of ChaCha on the input words in
 * |input| and writes the 64 output bytes to |output|. */
void chacha20(chacha_buf *output, const u32 input[16])
{
    u32 x[16];
    int i;

    for (int i = 0; i < 16; i++) {
        x[i] = input[i];
    }

    for (i = 20; i > 0; i -= 2) {
        QUARTERROUND(0, 4, 8, 12);
        QUARTERROUND(1, 5, 9, 13);
        QUARTERROUND(2, 6, 10, 14);
        QUARTERROUND(3, 7, 11, 15);
        QUARTERROUND(0, 5, 10, 15);
        QUARTERROUND(1, 6, 11, 12);
        QUARTERROUND(2, 7, 8, 13);
        QUARTERROUND(3, 4, 9, 14);
    }

    for (i = 0; i < 16; ++i)
        output->u[i] = x[i] + input[i];
}
```

我们可以发现， ChaCha20 的核心计算操作是 `ROTATE` ，即循环左移操作。该操作在 RV64GC 指令集上通常使用 `slli`, `srli`, `or` 三条指令实现。但在 RISC-V 的 Zbb 扩展中，提供了 `rol` 指令，可以直接实现循环左移操作。我们可以使用该指令来优化 ChaCha20 算法的性能。更进一步地， RISC-V Vector 以及 Zvbb 扩展也有指令提供了类似的功能，这一步留给选手根据相关的指令集手册和文档进行进一步的优化。

我们建议选手在实现了指令集扩展后，通过香山模拟器提供的性能计数器信息（该信息会输出到 xs-emu 的 stderr 输出中，可通过修改 Makefile 中的 `./xs-emu 2> /dev/null` 到 `./xs-emu 2> xs.log`）来分析性能瓶颈，进一步优化指令的排布、寄存器的分配、 Vector lmul 等参数的设置，来进一步提升性能。

## 香山单步调试

香山处理器是乱序多发射处理器，一个cycle可以同时执行多条指令，如果需要了解执行细节，可通过以下方式进行交互式调试：

```bash
make python-depends  # 下载python版香山（commit号同emu）、下载spike-dasm、安装python依赖
make python-debug    # 开始debug
```

如果一切正常，可以看见类似以下输出：
```
> chacha20-xiangshan/test.py(26)test_sim_top()
-> while True:
(XiangShan)
```

键入`xui`命令回车进入交互界面进行调试。常用调试命令如下：

1. `xstep <n>` 执行n个时钟周期，例如`xstep 10000`
1. `xistep [n]` 执行到下1次或者n次指令提交
1. `xreset` 重置电路
1. `xload` 加载指定bin文件
1. `xwatch SimTop_top.SimTop.timer` 观察当前cycle数

其他命令可通过`help`命令查看，部分命令支持tab补齐，例如xload。XSPdb参考链接：[https://github.com/OpenXiangShan/XSPdb](https://github.com/OpenXiangShan/XSPdb)。用户可参考[Pdb手册](https://docs.python.org/3/library/pdb.html)，在`XSPython/XSPdb/xspdb.py`中添加自定义命令。


## 推荐阅读

1. [OpenSSL 中的 ChaCha20 加密算法的 RISC-V Zvbb 汇编实现](https://github.com/openssl/openssl/blob/openssl-3.5.0-beta1/crypto/chacha/asm/chacha-riscv64-v-zbb.pl)

2. [OpenSSL 中使用 Zbb 扩展优化 Chacha20 算法 的实现](https://github.com/openssl/openssl/commit/ca6286c382a7eb527fac9aba2a018354acb27b16)
