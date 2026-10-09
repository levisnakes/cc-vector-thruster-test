# CC Vector Thruster Test

ComputerCraft program that tests every computer control on a Create Propulsion: Simulated vector thruster: creative, FE (normal) or liquid. It checks the nozzle angle range and step size, the throttle, and the creative thrust output. Then it switches to manual control, with WASD to aim and Q/E to change the throttle. Results are also saved to `vector_test.log`.

## Install

```
wget https://raw.githubusercontent.com/levisnakes/cc-vector-thruster-test/main/vector_test.lua vector_test.lua
```

Run it with `vector_test`. The throttle test asks before running, because thrust can move the ship.
