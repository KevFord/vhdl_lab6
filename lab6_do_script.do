
#Restart simulation
restart -f

# Define all input signals, reset active
force clk 0 0, 1 10 ns -r 20 ns
force valid_in 0
force reset 1

run 25 ns

force reset 0
# Set input vector to 123
force input_vector "01111011"

run 25 ns

force valid_in 1
run 25 ns
force valid_in 0

run 1 us

force valid_in 0

run 25 ns

# Set input vector to 56
force input_vector "00111000"

run 25 ns

force valid_in 1
run 25 ns
force valid_in 0

run 1 us

# Set input vector to 10
force input_vector "00001010"

run 25 ns

force valid_in 1
run 25 ns
force valid_in 0

run 1 us