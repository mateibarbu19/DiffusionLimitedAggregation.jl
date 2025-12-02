# Generated with Gemini
# Twicked by me

# --- Configuration ---
JULIAC   = juliac
OUT_DIR  = build/bin

# List all directories containing source code here
SRC_DIRS = src/serial src/parallel

# 1. Automatic Discovery
#    Find all .jl files in the listed directories
ALL_SRCS := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.jl))

#    Create target names (e.g., build/bin/Solver)
#    This takes the filename (not the full path) and prepends the output dir
AUTO_TARGETS := $(patsubst %.jl,$(OUT_DIR)/%,$(notdir $(ALL_SRCS)))

# 2. Custom Overrides (Optional)
#    If specific files need custom output names, define them here.
CUSTOM_TARGETS = $(OUT_DIR)/my-app

# --- Setup Search Paths (Magic) ---
# Tell Make to search for .jl files in all SRC_DIRS
vpath %.jl $(SRC_DIRS)

# --- Targets ---

# Main target: Build everything found + custom targets
all: $(AUTO_TARGETS) $(CUSTOM_TARGETS)

# 3. Pattern Rule
#    How to build any executable in build/bin from a .jl file found in vpath.
#    $@ = target (build/bin/Name)
#    $< = dependency (found source file, e.g., src/parallel/Name.jl)
$(OUT_DIR)/%: %.jl | $(OUT_DIR)
	@echo "Building $@ from $<..."
	$(JULIAC) --trim --output-exe $(notdir $@) $<
	@mv $(notdir $@) $(OUT_DIR)

# 4. Specific Rule for 'main'
#    Since we use vpath, we only need the filename 'Improved22.jl'
$(OUT_DIR)/main: src/DiffusionLimitedAggregation.jl | $(OUT_DIR)
	@echo "Building custom app $@ from $<..."
	$(JULIAC) --trim --output-exe $(notdir $@) --bundle build .

# Directory creation
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

clean:
	rm -rf build

.PHONY: all clean
