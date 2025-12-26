@echo off

pushd tests
if not exist "..\reports" mkdir "..\reports"

for %%f in (*.js) do (
    echo Running the test: %%f
    k6 run "%%f"
)

popd
