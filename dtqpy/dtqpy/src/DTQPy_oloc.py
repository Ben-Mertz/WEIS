#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Aug  3 08:33:16 2021

@author: athulsun
"""

from mat4py import loadmat
from scipy.signal import filtfilt
import numpy as np
from scipy.interpolate import interp1d,PchipInterpolator
import matplotlib.pyplot as plt
import os
import sys
import pickle

from dtqpy.src.classes.DTQPy_CLASS_OPTS import *
from dtqpy.src.classes.DTQPy_CLASS_SETUP import *
from dtqpy.src.DTQPy_solve import DTQPy_solve

def BuildLambda(Ax):
        return lambda t: Ax(t)

def TVmat2cell(f,time):
    """
    function to convert nt*nx*nz matrix to nx*nz cell

    """
    # evaluate function
    At = f(time)
    s = np.shape(At)
    
    
    if len(s) ==4:
        At = np.squeeze(At)
    elif len(s) == 3:
        At = np.squeeze(At)
        At= At.T
   
    # get size
    try:
        null,m,n = np.shape(At)
    except:
        null,m = np.shape(At)
        n = 1
    
    # initialize storage
    A = np.empty((m,n),dtype = 'O')
    
    

    for i in range(m):
        for j in range(n):
            try:
                Ax = PchipInterpolator(np.squeeze(time),At[:,i,j],axis = 0)
            except:
                Ax = PchipInterpolator(np.squeeze(time),At[:,i],axis = 0)
                # work around, as defining lambda functions in a loop in python is tricky
            A[i,j] = BuildLambda(Ax)
            
    return A

def Generate_AddtionalConstraints(DescOutput,Cw,Dw,ws,W_fun,time,Qty,b,yw):
    indQty = DescOutput.index(Qty)
    
    Cqty = Cw[:,indQty,:]
    Dqty = Dw[:,indQty,:]
    Yoqty = yw[indQty,:]
    
    
    Cind_pp = PchipInterpolator(ws,Cqty.T,axis = 1)
    Dind_pp = PchipInterpolator(ws,Dqty.T,axis = 1)
    Yoind_pp = PchipInterpolator(ws,Yoqty, axis = 1)
    
    Cind_op = lambda w: Cind_pp(w)
    Dind_op = lambda w: Dind_pp(w)
    Yoind_op = lambda w: Yoind_pp(w)
    
    Z = [Simple_Linear_Constraints() for n in range(1)]

    linearZ = [Simple_Bounds() for n in range(2)]
    
    linearZ[0].right = 2; linearZ[0].matrix = TVmat2cell(lambda t: Cind_op(W_fun(t)),time)
    linearZ[1].right = 1; linearZ[1].matrix = TVmat2cell(lambda t: Dind_op(W_fun(t)),time)
    
    Z[0].linear = linearZ
    Z[0].b = lambda t: b - Yoind_op(W_fun(t))
    
    
    
    return Z
    


def DTQPy_oloc(LinearModels,disturbance,OutputCon_flag = False):
    
    # load linear models
    Aw = np.transpose(LinearModels.A_ops,(2,0,1))
    Bw = np.transpose(LinearModels.B_ops,(2,0,1))
    Cw = np.transpose(LinearModels.C_ops,(2,0,1))
    Dw = np.transpose(LinearModels.D_ops,(2,0,1))
    
    DescOutput = LinearModels.DescOutput
    DescStates = LinearModels.DescStates
    DescCtrl = LinearModels.DescCntrlInpt
    
    # operating points
    xw = LinearModels.x_ops
    uw = LinearModels.u_ops
    yw = LinearModels.y_ops; 
    
    # wind speeds
    ws = LinearModels.u_h

    # construct LPV models
    # A matrix   
    A_op_pp = PchipInterpolator(ws, Aw, axis = 0)
    A_op = lambda w: A_op_pp(w)

    # Bmatrix
    B_op_pp = PchipInterpolator(ws, Bw, axis = 0)
    B_op = lambda w: B_op_pp(w)

    # Cmatrix
    C_op_pp = PchipInterpolator(ws,Cw,axis = 0)
    C_op = lambda w: C_op_pp(w)

    # Dmatrix
    D_op_pp = PchipInterpolator(ws,Dw,axis = 0)
    D_op = lambda w: D_op_pp(w)

    # control operating points
    Uo_pp = PchipInterpolator(ws,uw,axis = 1)
    Uo_fun = lambda w: Uo_pp(w)

    # state operating points
    Xo_pp = PchipInterpolator(ws, xw, axis = 1)
    Xo_fun = lambda w: Xo_pp(w)

    # outputs
    Yo_pp = PchipInterpolator(ws, yw, axis = 1)
    Yo_fun = lambda w: Yo_pp(w)
    
    # get state indices
    iGenSpeed = DescStates.index('ED First time derivative of Variable speed generator DOF (internal DOF index = DOF_GeAz), rad/s')
    iPtfmPitch = DescStates.index('ED Platform pitch tilt rotation DOF (internal DOF index = DOF_P), rad')
    
    iGenTorque = DescCtrl.index('ED Generator torque, Nm')
    iBldPitch = DescCtrl.index('ED Extended input: collective blade-pitch command, rad')
    
    # first time derivative of state operating points
    DXo_pp = Xo_pp.derivative 
    DXo_pp = DXo_pp(nu=1)
    DXo_fun = lambda w: DXo_pp(w)

    Wind_o = disturbance
    Wind_speed = np.array(Wind_o['Wind'])
    tt = np.array(Wind_o['Time'])
    tt = tt[None].T
    
    t0 = tt[0][0]
    tf = tt[-1][0]

    filterflag = 0
    
    

    if filterflag:
        t_f = 1
        dt = tt[2,0]-tt[1,0]
        nb = int(np.floor(t_f/dt))
        b = np.ones((nb,))/nb
        a = b*nb
        Wind_speed = filtfilt(b,1,Wind_speed,axis = 0)
        
    
    opts = options()

    opts.dt.nt = 1000
    opts.solver.tolerence = 1e-10
    opts.solver.maxiters = 1000000
    opts.solver.function = 'pyoptsparse'

    time = np.linspace(tt[0],tt[-1],opts.dt.nt)
    W_pp = PchipInterpolator(np.squeeze(tt),np.squeeze(Wind_speed))
    dW_pp = W_pp.derivative 
    dW_pp = dW_pp(nu = 1)

    DW_fun = lambda t: dW_pp(t)
    W_fun = lambda t: W_pp(t)

    DXoDt_fun = lambda t: (-DXo_fun(W_fun(t)).T*DW_fun(t)).T

    

    ## Disc2 cont

    def BuildFunction(w_ops,X):
        Xpp = PchipInterpolator(w_ops,X)
        return lambda w: Xpp(w)

    # Generator speed function
    GS_fun = BuildFunction(ws,xw[iGenSpeed,:])

    # -1*GS function
    GSn_fun = BuildFunction(ws,-xw[iGenSpeed,:])

    # Generator torque
    GT_fun = BuildFunction(ws,uw[iGenTorque,:])

    # -Generator torque
    GTn_fun = BuildFunction(ws,-uw[iGenTorque,:])

    # Blade pitch
    BP_fun = BuildFunction(ws,uw[iBldPitch,:])

    # Generator power
    GP_fun = BuildFunction(ws,-uw[iGenTorque,:]*xw[iGenSpeed,:])

    # State operating point values
    r = Xo_fun(ws)
    
    # Constraints generated from output
    OutputCon_flag = True
    
    if OutputCon_flag:
        Qty = "ED TwrBsFxt, (kN)"
        
        Z = Generate_AddtionalConstraints(DescOutput, Cw, Dw, ws, W_fun, time, Qty,5000,yw)

    # lambda function to find the values of lambda function at specific indices
    indexat = lambda expr,index: expr[index,:]

    # get shape
    nws,nx,nu = np.shape(Bw)

    # initialize
    ub = np.ones((nx,1))*np.inf
    lb = -np.ones((nx,1))*np.inf

    # set ub values for PtfmPitch and Genspeed
    ub[iPtfmPitch] = np.deg2rad(6)
    ub[iGenSpeed] = 0.7913+0.0001

    # initialize
    UBx = np.empty((nx,1),dtype = 'O')
    LBx = np.empty((nx,1),dtype = 'O')

    # need this function to define anaonymous functions in a loop in python
    def BuildLambdaUB(ub,indexat,Xo_fun,W_fun,i):
        return lambda t: ub - indexat(Xo_fun(W_fun(t)),i)

    # build ub and lb functions
    for i in range(nx):
        UBx[i,0] = BuildLambdaUB(ub[i],indexat,Xo_fun,W_fun,i)
        LBx[i,0] = BuildLambdaUB(lb[i],indexat,Xo_fun,W_fun,i)

    # control bounds
    UBc = np.array([[lambda t: W_fun(t)-W_fun(t)],
                    [lambda t: max(uw[1,:])-GT_fun(W_fun(t))],
                    [lambda t: max(uw[2,:])-BP_fun(W_fun(t))]])

    LBc = np.array([[lambda t: W_fun(t)-W_fun(t)],
                    [lambda t: min(uw[1,:])-GT_fun(W_fun(t))],
                    [lambda t: min(uw[2,:])-BP_fun(W_fun(t))]])

    # initial state
    X0_n = np.zeros((nx,1))
    X0_n[0:8] = np.array( [[0.0493],
        [0.1957],
        [0.0000],
        [0.0001],
        [0.7913],
            [0],
            [0],
            [0]])
    
    
    UBs = X0_n - Xo_fun(W_fun(0))[None].T
    LBs = X0_n - Xo_fun(W_fun(0))[None].T

    # UB,LB
    UB = [Simple_Bounds() for n in range(3)]
    LB = [Simple_Bounds() for n in range(3)]

    # states
    UB[0].right = 2
    UB[0].matrix = UBx
    LB[0].right = 2
    LB[0].matrix = LBx

    # control bounds
    UB[1].right = 1
    UB[1].matrix = UBc
    LB[1].right = 1
    LB[1].matrix = LBc

    # initial state
    UB[2].right = 4
    UB[2].matrix = UBs
    LB[2].right = 4
    LB[2].matrix = LBs

    # lagrange terms

    R1 = 1e-8; R2 = 1e+8

    lx = 0

    L = [LQ_objective() for n in range(5)]

    # uRu
    L[lx].left = 1
    L[lx].right = 1
    L[lx].matrix = np.diag([0,R1,R2])

    lx = lx+1

    # uPX
    L[lx].left = 1
    L[lx].right = 2
    Lmat = np.zeros((nu,nx)); Lmat[iGenTorque,iGenSpeed] = -1
    L[lx].matrix = Lmat

    lx = lx+1

    L[lx].left = 0;
    L[lx].right = 1
    L2mat = np.zeros((1,nu),dtype = 'O')
    L2mat[0,iGenTorque] = lambda t: GSn_fun(W_fun(t))
    L[lx].matrix = L2mat

    lx = lx+1
    L[lx].left = 0
    L[lx].right = 2
    L3mat = np.zeros((1,nx),dtype = 'O')
    L3mat[0,iGenSpeed] = lambda t: GTn_fun(W_fun(t))
    L[lx].matrix = L3mat

    lx = lx+1

    L[lx].left = 0
    L[lx].right = 0
    L4mat = np.empty((1,1),dtype = 'O')
    L4mat[0,0] = lambda t: GP_fun(W_fun(t))
    L[lx].matrix = L4mat

    # 
    scale = Scaling(right = 1, matrix = np.array([1,1e-16,1e-4]))


    # setup
    s = setup()
    s.A = TVmat2cell(lambda t: A_op(W_fun(t)),time)
    s.B = TVmat2cell(lambda t: B_op(W_fun(t)),time)
    s.d = TVmat2cell(DXoDt_fun,time)
    
    if OutputCon_flag:
        s.Z = Z
        
    s.Lagrange = L
    s.UB = UB
    s.LB = LB
    s.Scaling = scale
    s.t0 = t0
    s.tf = tf
    
    [T,Ul,Xl,P,F,internal,opts] = DTQPy_solve(s,opts)

    # calculate offset
    Xo_off = np.squeeze(Xo_fun(W_fun(T))).T 
    Uo_off = np.squeeze(Uo_fun(W_fun(T))).T 
    Yo_off = np.squeeze(Yo_fun(W_fun(T))).T

    # Add offset to estimated states
    X =  Xl + Xo_off
    U = Ul + Uo_off
    
    if OutputCon_flag:
        yl = np.zeros((opts.dt.nt,np.shape(yw)[0]))
        for i in range(len(T)):
            t = T[i,0]
            w = W_fun(t)
            
            C = C_op(w)
            D = D_op(w)
            
            xl = Xl[i,:]
            ul = Ul[i,:]
            
            yl[i,:] = np.squeeze(np.dot(C,xl.T) + np.dot(D,ul.T)) 
            
        Y = yl + Yo_off
            

    # plot
    fig, ((ax1,ax2,ax3)) = plt.subplots(3,1,)

    # wind
    ax1.plot(T,U[:,0])
    ax1.set_title('Wind Speed [m/s]')
    ax1.set_xlim([t0,tf])

    # torue
    ax2.plot(T,U[:,iGenTorque]/1e+07)
    ax2.set_ylim([1.8,2])
    ax2.set_title('Gen Torque [MWm]')
    ax2.set_xlim([t0,tf])

    # blade pitch
    ax3.plot(T,U[:,iBldPitch])
    #ax3.set_ylim([0.2, 0.3])
    ax3.set_title('Bld Pitch [rad/s]')
    ax3.set_xlim([t0,tf])

    fig.subplots_adjust(hspace = 0.65)
    
    
    if OutputCon_flag:
        fig2, ((ax1,ax2,ax3)) = plt.subplots(3,1)
    else:
        fig2, ((ax1,ax2)) = plt.subplots(2,1)
            

    # PtfmPitch
    ax1.plot(T,np.rad2deg(X[:,iPtfmPitch]))
    ax1.set_xlim([t0,tf])
    ax1.set_title('Ptfm Pitch [deg]')

    # FenSpeed
    ax2.plot(T,X[:,iGenSpeed])
    ax2.set_xlim([t0,tf])
    ax2.set_title('Gen Speed [rad/s]')
    
    if OutputCon_flag:
        Yind = DescOutput.index(Qty)
        ax3.plot(T,Y[:,Yind])
        ax3.set_xlim([t0,tf])
        ax3.set_title(Qty)

    fig2.subplots_adjust(hspace = 0.65)
    
    plt.show()
    
    return T,U,X,Y
    

if __name__ == '__main__':
    ex_name = weis_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))))
    
    
    Wind_file = ex_name + os.sep + 'examples' + os.sep + "13_DTQP" + os.sep + "dist.pkl"
    with open(Wind_file,"rb") as handle:
        Wind_o = pickle.load(handle)
    
    
    Linfile = ex_name + os.sep + 'examples' + os.sep + "13_DTQP" + os.sep +'LinearTurbine.pkl'
    with open(Linfile,"rb") as handle:
        LinearModels = pickle.load(handle)
    
    
    

    DTQPy_oloc(LinearModels,Wind_o)


