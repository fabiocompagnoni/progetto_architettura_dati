# Compilazione del report.
#   make        -> compila le figure standalone e poi main.pdf
#   make figure -> solo le figure
#   make clean  -> rimuove i file intermedi
#   make dist-clean -> rimuove anche i PDF

FIG_SRC := $(wildcard figure/*.tex)
FIG_PDF := $(FIG_SRC:.tex=.pdf)
CAP     := $(wildcard capitoli/*.tex)

LATEXMK := latexmk -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all figure clean dist-clean

all: main.pdf

figure: $(FIG_PDF)

# ogni figura è un documento standalone
figure/%.pdf: figure/%.tex
	cd figure && $(LATEXMK) $(notdir $<) >/dev/null

main.pdf: main.tex preambolo.tex frontespizio.tex bibliografia.bib $(CAP) $(FIG_PDF)
	$(LATEXMK) main.tex

clean:
	$(LATEXMK) -c main.tex >/dev/null 2>&1 || true
	cd figure && $(LATEXMK) -c >/dev/null 2>&1 || true

dist-clean: clean
	$(LATEXMK) -C main.tex >/dev/null 2>&1 || true
	rm -f figure/*.pdf
