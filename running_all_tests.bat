@echo off
for %%f in (.\tests\*.js) do (
    echo Running the test: %%f
    k6 run %%f
)
