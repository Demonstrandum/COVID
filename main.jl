#!/usr/bin/env julia
#
println("\nWait...")

import CSV
import Dates

using Plots
using Plots.PlotMeasures
using Interpolations

macro pp(var)
	return :(
		println();
		show(
			IOContext(stdout, :limit => true),
			"text/plain", $var);
		println();
	)
end

countries = Dict{String, Array{Int, 1}}()
#=
# e.g.
countries = Dict(
	"Norway" => [
		0; 0; 1; 3; 9; ...
	]
)
=#

function iterate_rows(lambda::Function, filename::String)
	data_file = open(filename, "r")
	header = (data_file
		|> eachline
		|> first 
		|> s -> split(s, ",")
		|> xs -> map(string, xs))

	rows = CSV.Rows(
		data_file,
		header=header,
		normalizenames=true)
	
	for row in rows
		lambda(row)
	end

	close(data_file)
	return header
end

# Select counting type from command line.
counting_types = Set(["deaths", "recovered", "confirmed"])
counting_type = "confirmed"
cumulative = false

if isinteractive()
	print("\nDisplay [C]onfirmed/[d]eaths/[r]ecovered [C/d/r]: ")
	input = readline() |> lowercase

	what_data = ""

	if input == "" || input == "c"
		counting_type = "confirmed"
		what_data = "confirmed cases"
	elseif input == "d"
		counting_type = "deaths"
		what_data = "deaths"
	elseif input == "r"
		counting_type = "recovered"
		what_data = "recovered cases"
	else
		println("Unrecognised input '$(input)'.")
		throw("Bad input.")
	end

	print("Display cumulative $(what_data)? [y/N]: ")
	input = readline() |> lowercase

	if input == "" || input == "n"
		cumulative = false
	elseif input == "y"
		cumulative = true
	else
		println("Unrecognised input '$(input)'.")
		throw("Bad input.")
	end
else
	for arg in ARGS
		global counting_type
		lower = lowercase(arg)
		
		if lower in counting_types
			counting_type = lower
		elseif lower == "cumulative"
			cumulative = true
		end
	end
end

filename = "time_series_covid19_$(counting_type)_global.csv"
date_range = Nothing

println("\nReading Data.\n")

header = iterate_rows(filename) do row
	global date_range
	global countries

	date_range = 5:length(row)
	entry_exists = haskey(countries, row.Country_Region)

	cases_list = []
	previous = 0
	for date_index in date_range
		cases = parse(Int, row[date_index])
		if !cumulative
			# For some damn reason, the apparently
			# cumulative sum of cases is not in ascending
			# order, meaning a negative amount of people got
			# the coronavirus one day... In Japan one day, -417
			# people got the Coronavirus! Go Japan!

			if cases < previous
				# If one day has negative cases,
				# just ignore it and carry forward the
				# last value.
				cases = previous
			end
			tmp_cases = cases
			cases -= previous
			previous = tmp_cases
		end
		push!(cases_list, cases)
	end

	if entry_exists
		countries[row.Country_Region] += cases_list
	else
		countries[row.Country_Region] = cases_list
	end
end

function split_every(xs::AbstractArray{Number, 1}, grouping::UInt)
	groups::AbstractArray{AbstractArray{Number, 1}, 1} = []
	group::AbstractArray{Number, 1} = []
	i = 1

	for x in xs
		push!(group, x)
		
		if i % grouping == 0
			push!(groups, group)
			group = []
		end

		i += 1
	end
	i -= 1

	remainder = length(xs) % grouping
	if remainder != 0
		push!(groups, xs[end-remainder+1:end])
	end

	return groups
end

function running_mean(xs::AbstractArray{Number, 1}, grouping::UInt)
	averages::Array{Float64, 1} = map(
		x -> sum(x) / length(x),
		split_every(xs, grouping))
	return averages
end

function unamerican(us_date::String)
	m_d_y = split(us_date, "/")
	m_d_y[3] = "20" * m_d_y[3]
	m_d_y = map(s -> parse(UInt, s), m_d_y)
	return Dates.Date(m_d_y[3], m_d_y[1], m_d_y[2])
end

function nice_date(date::Dates.Date)
	year = Dates.year(date)
	year_s = string(year)[end-1:end]
	month_s = Dates.monthabbr(Dates.month(date))
	day_s = string(Dates.day(date))
	return "$(day_s) $(month_s)"
end

function nice_number(num::Number)
	s = string(Int(ceil(num)))
	if length(s) < 3
		return s
	end

	places = []
	i = length(s)
	while i > 2
		pushfirst!(places, s[i-2:i])
		i -= 3
	end
	
	if i > 0
		pushfirst!(places, s[1:i])
	end

	return join(places, "\u2009")  # Thin space (\,)
end

dates = map(unamerican, header[date_range])

#@pp countries
#@pp dates

selected_countries = [
	"Norway",
	"US",
	"United Kingdom",
	"Spain",
	"Sweden",
	"Italy",
	"China",
	"Thailand",
	"Finland",
	"Denmark",
	"Mexico",
	"Canada",
	"Germany",
	"Greece",
	"Korea, South",
	"Japan",
	"Slovakia",
	"Australia",
	"Israel",
	"France",
	"Turkey",
	"India",
	"Pakistan",
	"Netherlands",
	"Switzerland"
]

pyplot()

LMR = "Latin Modern Roman"
LMRC = LMR * " Caps"

default(
	titlefont  = font(13, LMRC, halign = :left),
	legendfont = font( 5, LMR),
	ytickfont  = font( 7, "CMU Serif"),
	xtickfont  = font( 7, "Input Mono"))

normal(x) = x / 255

RED   = RGB(map(normal, [179,  30, 107])...)
AMBER = RGB(map(normal, [232, 195,  28])...)
GREEN = RGB(map(normal, [ 28, 180,  90])...)

plots = []

grouping_every = 4
interp = 3
indecies = ceil(length(dates) / grouping_every)
data_points = UInt(indecies * interp)

date_inverse(x) = Int(ceil(
	x * grouping_every / interp) + 1)

println("\nBuilding plots.\n")

for country in selected_countries
	dates_formatted = map(nice_date, dates)

	xs = 1:data_points
	ys = running_mean(
		Array{Number, 1}(countries[country]),
		UInt(grouping_every))
	ys = interpolate(ys, BSpline(Quadratic(Natural(OnCell()))))
	ys = [ys((indecies - 1)*(x - 1) / (data_points - 1) + 1) for x in xs]
	ys = [y < 0 ? 0 : y for y in ys]


	cases_start = 1
	# When number of cases > 9
	#=
	acc = 0
	for y in ys
		if acc > 9
			break
		end
		if !cumulative
			acc += y
		else
			acc = y
		end
		cases_start += 1
	end
	println(cases_start)
	=#

	xs = xs[cases_start:end]
	ys = ys[cases_start:end]


	if country == "Korea, South"
		country = "South Korea"  # Why did they name it this way..?
	elseif country == "US"
		country = "United States"  # For consistency with UK.
	end

	y_max = maximum(ys)
	y_min = minimum(ys)
	y_latest = ys[end]
	y_ratio = y_latest / y_max

	print("$(country): [$(round(y_min)); $(round(y_max))]")
	println(" -- ratio: $(round(y_ratio, digits=5))")


	color = Nothing

	if y_ratio < 0.11
		color = GREEN
	elseif y_ratio < 0.343
		color = AMBER
	else
		color = RED
	end

	if cumulative
		color = :blue
	end

	p = plot(xs, ys,
		title = " " * country,
		titlelocation = :left,
		lab = titlecase(counting_type),
		legend = false,
		linecolor = color,
		seriestype = :path,
		xrotation = 60,
		yformatter = nice_number,
		xformatter = i -> nice_date(dates[date_inverse(i)]),
		dpi = 230)
	
	push!(plots, p)
end

data_rep = if cumulative
	"Cumulative"
else
	"Daily-Cases"
end
title_name = "COVID-19 — $(titlecase(counting_type)) ($(data_rep))"

grid_shape = UInt(ceil(sqrt(length(selected_countries))))
l = @layout [
	a{0.1h}; grid(grid_shape, grid_shape); b{0.1h}
]


title_plot = plot(
	annotation = (
		0.5, 0.5,
		text(title_name, font(LMRC, 30))),
	framestyle = :none)

key_font = font(LMRC, 20)
marker(color) = text("█████", font("sans-serif", 24, color=color))

key_plot = plot(
	annotation = [
		(
			0.25, 0.75,
			marker(RED)
		)
		(
			0.5, 0.75,
			marker(AMBER)
		)
		(
			0.75, 0.75,
			marker(GREEN)
		)
		(
			0.25, 0.25,
			text("Needs Action", key_font)
		)
		(
			0.5, 0.25,
			text("Nearly There", key_font)
		)
		(
			0.75, 0.25,
			text("Successful", key_font)
		)
	],
	framestyle = :none)

p = plot(title_plot, plots..., key_plot,
	plot_title = title_name,
	margin = 10px,
	size = (2000, 2500),
	layout = l)


println("\nCounting $(counting_type).")
println("Showing $(cumulative ? "" : "non-")cumulative data.")

println("\nSaving image.\n")
savefig(p, "plots.png")
cp(
	"plots.png",
	"COVID-19_$(counting_type)_$(lowercase(data_rep))_plots.png",
	force=true)
println("\nSaved!\n")


