#################################################
# 10. Variable Definitions and Descriptive Tables
#################################################
# Run after setting the working directory to the repository root.
# Outputs: Table 2, Verification scope, Table S10

##### LaTeX Table Writing Function
escape_tex = function(x) {
  x = gsub("%", "\\%", x, fixed = TRUE)
  x = gsub("_", "\\_", x, fixed = TRUE)
  x = gsub("&", "\\&", x, fixed = TRUE)
  x = gsub("^2", "$^2$", x, fixed = TRUE)
  x
}

write_table = function(data, file, columns) {
  header = paste(escape_tex(names(data)), collapse = " & ")
  rows = apply(data, 1, function(x) {
    paste0(paste(escape_tex(x), collapse = " & "), " \\\\")
  })

  output = c(
    paste0("\\begin{tabular}{", columns, "}"),
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    rows,
    "\\bottomrule",
    "\\end{tabular}"
  )

  writeLines(output, file)
}

#################################################
# Table 2. Variable Definitions
#################################################

data = read.csv("data/support/covariate_definitions.csv", check.names = FALSE)
output = data

write.csv(output, "result/Table 2.csv", row.names = FALSE)
write_table(output, "result/Table 2.tex", "p{0.44\\linewidth}ll")

#################################################
# Unnumbered Reference: Verification Scope (not a table in the current manuscript)
#################################################

data = read.csv("data/support/verification_scope.csv", check.names = FALSE)
output = data

write.csv(output, "result/Verification scope.csv", row.names = FALSE)
write_table(
  output,
  "result/Verification scope.tex",
  "p{0.18\\linewidth}p{0.34\\linewidth}p{0.37\\linewidth}"
)

#################################################
# Table S10. Documentary Evidence for Policy Timing
#################################################

data = read.csv("data/support/policy_dates.csv", check.names = FALSE)
output = data

write.csv(output, "result/Table S10.csv", row.names = FALSE)
write_table(
  output,
  "result/Table S10.tex",
  "p{0.18\\linewidth}p{0.35\\linewidth}p{0.36\\linewidth}"
)
