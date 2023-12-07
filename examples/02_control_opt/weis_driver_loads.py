import os
import time
import sys

from weis.glue_code.runWEIS     import run_weis
from wisdem.commonse.mpi_tools  import MPI

## File management
run_dir                 = os.path.dirname( os.path.realpath(__file__) )
fname_wt_input          = run_dir + os.sep + 'IEA-15-240-RWT.yaml'
fname_modeling_options  = run_dir + os.sep + 'modeling_options_loads.yaml'
fname_analysis_options  = run_dir + os.sep + 'analysis_options_loads.yaml'


tt = time.time()
wt_opt, modeling_options, opt_options = run_weis(fname_wt_input, fname_modeling_options, fname_analysis_options)

if MPI:
    rank = MPI.COMM_WORLD.Get_rank()
else:
    rank = 0
if rank == 0:
    print("Run time: %f"%(time.time()-tt))
    sys.stdout.flush()
