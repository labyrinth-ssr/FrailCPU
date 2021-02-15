MDBOOK = mdbook

.PHONY: doc-build doc-serve

doc-build:
	cd doc; $(MDBOOK) build

doc-serve:
	cd doc; $(MDBOOK) serve
