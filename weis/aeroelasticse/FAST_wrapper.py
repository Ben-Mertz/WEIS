import os
import subprocess
import platform
import time

class FAST_wrapper(object):

    def __init__(self, **kwargs):

        self.FAST_exe = None   # Path to executable
        self.FAST_InputFile = None   # FAST input file (ext=.fst)
        self.FAST_directory = None   # Path to fst directory files
        self.debug_level = 0 #(0:quiet, 1:output task description, 2:full FAST stdout)

        # Optional population class attributes from key word arguments
        for k, w in kwargs.items():
            try:
                setattr(self, k, w)
            except:
                pass

        super(FAST_wrapper, self).__init__()

    def execute(self):

        self.input_file = os.path.join(self.FAST_directory, self.FAST_InputFile)

        try:
            if platform.system()!='Windows' and self.FAST_exe[-4:]=='.exe':
                self.FAST_exe = self.FAST_exe[:-4]
        except:
            pass

        exec_str = []
        exec_str.append(self.FAST_exe)
        exec_str.append(self.FAST_InputFile)

        olddir = os.getcwd()
        os.chdir(self.FAST_directory)

        if self.debug_level > 0:
            print ("EXECUTING OpenFAST")
            print ("Executable: \t", self.FAST_exe)
            print ("Run directory: \t", self.FAST_directory)
            print ("Input file: \t", self.FAST_InputFile)
            print ("Exec string: \t", exec_str)

        start = time.time()
        if self.debug_level > 1:
            _ = subprocess.run(exec_str, check=True)
        else:
            _ = subprocess.run(exec_str, stdout=subprocess.DEVNULL, check=True)
        runtime = time.time() - start
        print('Runtime: \t{} = {:<6.2f}s'.format(self.FAST_InputFile, runtime))

        os.chdir(olddir)

if __name__=="__main__":


    fast = FAST_wrapper(debug_level=2)

    # Path to fst directory files

    fast.FAST_exe = 'C:/Users/egaertne/WT_Codes/openfast-dev/build/glue-codes/openfast/openfast.exe'   # Path to executable
    # fast.FAST_InputFile = 'test.fst'   # FAST input file (ext=.fst)
    # fast.FAST_directory = 'C:/Users/egaertne/WISDEM/AeroelasticSE/src/AeroelasticSE/FAST_mdao/temp/OpenFAST'   # Path to fst directory files
    fast.FAST_InputFile = 'RotorSE_FAST_5MW_0.fst'   # FAST input file (ext=.fst)
    fast.FAST_directory = "C:/Users/egaertne/WISDEM/RotorSE_yaml/RotorSE/src/rotorse/temp/RotorSE_FAST_5MW"   # Path to fst directory files

    fast.execute()
