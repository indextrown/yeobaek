.DEFAULT_GOAL := help

POSITIONAL_GOALS := $(filter-out module demo help,$(MAKECMDGOALS))
MODULE_NAME := $(if $(MODULE),$(MODULE),$(firstword $(POSITIONAL_GOALS)))
DEMO_ENABLED := $(if $(filter 1 true yes,$(DEMO)),true,$(if $(filter demo,$(MAKECMDGOALS)),true,false))

.PHONY: help module demo

help:
	@echo "Feature module commands"
	@echo "  make module SampleFeature"
	@echo "  make module SampleFeature demo"

module:
	@bash Scripts/make-feature-module.sh "$(MODULE_NAME)" "$(DEMO_ENABLED)"

demo:
	@:

ifneq ($(strip $(POSITIONAL_GOALS)),)
.PHONY: $(POSITIONAL_GOALS)
$(POSITIONAL_GOALS):
	@:
endif
