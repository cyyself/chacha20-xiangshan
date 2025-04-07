CROSS_COMPILE := riscv64-linux-gnu-
LOADER := qemu-riscv64
CROSS_CC := $(CROSS_COMPILE)gcc
CROSS_LD := $(CROSS_COMPILE)ld
CROSS_OBJCOPY := $(CROSS_COMPILE)objcopy
CFLAGS := -O3 -Ilib -Isrc -fno-builtin -static
CROSS_CFLAGS := -march=rv64gc -mcmodel=medany
BAREMETAL_CFLAGS := -nostdlib
BENCH_LEN := 256

# CROSS_COMPILE linux
chacha20_linux-$(BENCH_LEN): src/bench-$(BENCH_LEN).o src/chacha20.o lib/textio.o lib/uart_stdout.o
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) -static -o $@ $^

# CROSS_COMPILE baremetal
chacha20_baremetal-$(BENCH_LEN): lib/am_start.S src/bench-$(BENCH_LEN).o src/chacha20.o lib/textio.o lib/uart_uartlite.o
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) $(BAREMETAL_CFLAGS) -T lib/linker.ld -o $@ $^

chacha20_baremetal-$(BENCH_LEN).bin: chacha20_baremetal-$(BENCH_LEN)
	$(CROSS_OBJCOPY) -O binary $^ $@

# CROSS_COMPILE objs
src/bench-$(BENCH_LEN).o: src/bench.c
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) $(BAREMETAL_CFLAGS) -DBENCH_LEN=$(BENCH_LEN) -c -o $@ $^

src/chacha20.o: src/chacha20.s
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) $(BAREMETAL_CFLAGS) -c -o $@ $^

lib/textio.o: lib/textio.c
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) $(BAREMETAL_CFLAGS) -c -o $@ $^

lib/uart_uartlite.o: lib/uart_uartlite.c
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) $(BAREMETAL_CFLAGS) -c -o $@ $^

lib/uart_stdout.o: lib/uart_stdout.c
	$(CROSS_CC) $(CFLAGS) $(CROSS_CFLAGS) -c -o $@ $^

# HOST objs
src/host/gen_answer: src/host/gen_answer.c src/host/chacha20_c.c
	$(CC) $(CFLAGS) -o $@ $^

answer:
	@mkdir -p answer

answer/$(BENCH_LEN).txt: src/host/gen_answer answer
	./src/host/gen_answer $(BENCH_LEN) 0xdeadbeef | grep "ans\[" > $@

xs-emu:
	if [ `nproc` -lt 8 ]; then \
		wget https://github.com/cyyself/chacha20-xiangshan/releases/download/beta/xs-emu-1t-1f23fd0f52.xz -O - | xz -d > $@; \
	else \
		wget https://github.com/cyyself/chacha20-xiangshan/releases/download/beta/xs-emu-8t-1f23fd0f52.xz -O - | xz -d > $@; \
	fi
	chmod +x $@

.PHONY: validate validate-rtl clean run

clean:
	rm -f chacha20_linux-* chacha20_baremetal-* lib/*.o src/*.o src/host/gen_answer

validate: chacha20_linux-$(BENCH_LEN) answer/$(BENCH_LEN).txt
	@$(LOADER) ./chacha20_linux-$(BENCH_LEN) | tail -n 16 | diff answer/$(BENCH_LEN).txt - && echo "Test passed"

validate-rtl: xs-emu chacha20_baremetal-$(BENCH_LEN).bin answer/$(BENCH_LEN).txt
	./xs-emu -i ./chacha20_baremetal-$(BENCH_LEN).bin --no-diff 2>/dev/null | grep "ans\[" | diff answer/$(BENCH_LEN).txt - && echo "Test passed"

run: xs-emu chacha20_baremetal-$(BENCH_LEN).bin
	./xs-emu -i ./chacha20_baremetal-$(BENCH_LEN).bin --no-diff 2>/dev/null

ready-to-run:
	wget https://github.com/OpenXiangShan/XSPdb/releases/download/v0.1.0-test/ready-to-run.tar.gz
	tar -xvf ready-to-run.tar.gz
	rm -f ready-to-run.tar.gz

XSPython:
	wget https://github.com/OpenXiangShan/XSPdb/releases/download/v0.1.0-test/XSPython-1f23fd0f5.tar.gz
	tar -xvf XSPython-1f23fd0f5.tar.gz
	rm -f XSPython-1f23fd0f5.tar.gz

python-depends: ready-to-run XSPython
	@echo "python3 -m pip install urwid capstone"
	python3 -m pip install urwid capstone

python-debug: chacha20_baremetal-$(BENCH_LEN).bin
	@echo "type command xui to enter XSPython interactive mode"
	@echo "type help for help"
	PYTHONPATH=. python3 test.py chacha20_baremetal-$(BENCH_LEN).bin
