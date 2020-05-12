#!/bin/sh

cd "$(dirname "$0")"

OUT="$(julia -e 'import Pkg; isempty(Iterators.filter(p -> p.name == "PackageCompiler", values(Pkg.dependencies()))) && println("[ERROR]: You need the `PackageCompiler'"'"' package to continue.")')"

[ ! -z "$OUT" ] && exit 1

if [ ! -f "sys_plots.so" ]; then
	echo "Compiling \`main.jl', generating sysimage (\`sys_plots.so')."

	julia -e 'using PackageCompiler
		create_sysimage([:Plots, :CSV, :Interpolations],
			sysimage_path="sys_plots.so",
			precompile_execution_file="../main.jl")'
else
	echo "Found already compiled \`sys_plots.so', using this."
fi

CMD="julia --sysimage sys_plots.so ../main.jl"

$CMD deaths cumulative
$CMD deaths
$CMD confirmed cumulative
$CMD confirmed
$CMD recovered cumulative
$CMD recovered

