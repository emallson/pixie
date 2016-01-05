all: help

EXTERNALS=externals

PYTHON ?= python2
PYTHONPATH=$$PYTHONPATH:$(EXTERNALS)/pypy

USE_GLOBAL_LOADPATH ?= False


COMMON_BUILD_OPTS?=--thread --gcrootfinder=shadowstack --continuation
JIT_OPTS?=--opt=jit
TARGET_OPTS?=target.py

# directory variables
prefix=/usr/local
exec_prefix=$(prefix)
bindir=$(exec_prefix)/bin
datarootdir=$(prefix)/share
datadir=$(datarootdir)

LIB_PATH=$(datadir)/pixie
BIN_PATH=$(bindir)/pixie

help:
	@echo "make help                   - display this message"
	@echo "make run                    - run the compiled interpreter"
	@echo "make run_interactive        - run without compiling (slow)"
	@echo "make build_with_jit         - build with jit enabled"
	@echo "make build_no_jit           - build without jit"
	@echo "make fetch_externals	   - download and unpack external deps"

build_with_jit: fetch_externals build_config.py
	@if [ ! -d /usr/local/include/boost -a ! -d /usr/include/boost ] ; then echo "Boost C++ Library not found" && false; fi && \
	$(PYTHON) $(EXTERNALS)/pypy/rpython/bin/rpython $(COMMON_BUILD_OPTS) --opt=jit target.py && \
	make compile_basics

build_no_jit: fetch_externals build_config.py
	@if [ ! -d /usr/local/include/boost -a ! -d /usr/include/boost ] ; then echo "Boost C++ Library not found" && false; fi && \
	$(PYTHON) $(EXTERNALS)/pypy/rpython/bin/rpython $(COMMON_BUILD_OPTS) target.py && \
	make compile_basics

build_no_jit_shared: fetch_externals build_config.py
	@if [ ! -d /usr/local/include/boost -a ! -d /usr/include/boost ] ; then echo "Boost C++ Library not found" && false; fi && \
	$(PYTHON) $(EXTERNALS)/pypy/rpython/bin/rpython $(COMMON_BUILD_OPTS) --shared target.py && \
	make compile_basics


compile_basics:
	@echo -e "\n\n\n\nWARNING: Compiling core libs. If you want to modify one of these files delete the .pxic files first\n\n\n\n"
	./pixie-vm -c pixie/uv.pxi -c pixie/io.pxi -c pixie/stacklets.pxi -c pixie/stdlib.pxi -c pixie/repl.pxi

build_preload_with_jit: fetch_externals build_config.py
	$(PYTHON) $(EXTERNALS)/pypy/rpython/bin/rpython $(COMMON_BUILD_OPTS) --opt=jit target_preload.py 2>&1 >/dev/null | grep -v 'WARNING'

build_preload_no_jit: fetch_externals build_config.py
	$(PYTHON) $(EXTERNALS)/pypy/rpython/bin/rpython $(COMMON_BUILD_OPTS) target_preload.py

build: fetch_externals build_config.py
	$(PYTHON) $(EXTERNALS)/pypy/rpython/bin/rpython $(COMMON_BUILD_OPTS) $(JIT_OPTS) $(TARGET_OPTS)

# build configuration
# should probably look into automake?
build_config.py:
	echo "USE_GLOBAL_LOADPATH = ${USE_GLOBAL_LOADPATH}" > $@
	echo "STDLIB_LOADPATH = \"${LIB_PATH}\"" >> $@

fetch_externals: $(EXTERNALS)/pypy externals.fetched

externals.fetched:
	echo https://github.com/pixie-lang/external-deps/releases/download/1.0/`uname -s`-`uname -m`.tar.bz2
	curl -L https://github.com/pixie-lang/external-deps/releases/download/1.0/`uname -s`-`uname -m`.tar.bz2 > /tmp/externals.tar.bz2
	tar -jxf /tmp/externals.tar.bz2 --strip-components=2
	touch externals.fetched


$(EXTERNALS)/pypy:
	mkdir $(EXTERNALS); \
	cd $(EXTERNALS); \
	curl https://bitbucket.org/pypy/pypy/get/81254.tar.bz2 >  pypy.tar.bz2; \
	mkdir pypy; \
	cd pypy; \
	tar -jxf ../pypy.tar.bz2 --strip-components=1

run:
	./pixie-vm


run_interactive:
	@PYTHONPATH=$(PYTHONPATH) $(PYTHON) target.py

run_interactive_stacklets:
	@PYTHONPATH=$(PYTHONPATH) $(PYTHON) target.py pixie/stacklets.pxi


run_built_tests: pixie-vm
	./pixie-vm run-tests.pxi

run_interpreted_tests: target.py
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) target.py run-tests.pxi

compile_tests:
	find "tests" -name "*.pxi" | xargs -L1 ./pixie-vm -l "tests" -c

compile_src:
	find * -name "*.pxi" | grep "^pixie/" | xargs -L1 ./pixie-vm $(EXTERNALS_FLAGS) -c

install: pixie-vm
	install -D pixie-vm $(DESTDIR)$(BIN_PATH)
	install -d $(DESTDIR)$(LIB_PATH)
	cp -R pixie $(DESTDIR)$(LIB_PATH)

clean_pxic:
	find * -name "*.pxic" | xargs --no-run-if-empty rm

clean: clean_pxic
	rm -rf ./lib
	rm -rf ./include
	rm -rf ./externals*
	rm -f ./pixie-vm
	rm -f ./*.pyc

.PHONY: build_config.py
