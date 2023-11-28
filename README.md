# iCESM1_2_0_1_geotrace_n02d

iCESM1.2 code with deep-time bug fixes (and tuning), which has been used in DeepMIP and MioMIP simulations.
This code has been ported on Derecho but not tested. Let me know if you find any problems with the porting.

References
* Zhu, J., Poulsen, C. J., & Tierney, J. E. (2019). Simulation of Eocene extreme warmth and high climate sensitivity through cloud feedbacks. Science Advances, 5(9), eaax1874. https://doi.org/10.1126/sciadv.aax1874
* Zhu, J., Poulsen, C. J., Otto-Bliesner, B. L., Liu, Z., Brady, E. C., & Noone, D. C. (2020). Simulation of early Eocene water isotopes using an Earth system model and its implication for past climate reconstruction. Earth and Planetary Science Letters, 537, 116164. https://doi.org/10.1016/j.epsl.2020.116164

How to run on Derecho
* set casename = test
* cd iCESM1_2_0_1_geotrace_n02d/scripts
* ./create_newcase -case {$casename} -res f19_g16 -mach derecho -compset B1850C5CN
* cd {$casename}
* ./xmlchange RUN_TYPE=hybrid,RUN_REFCASE=b.e12.B1850C5CN.f19_g16.iPI.01,RUN_REFDATE=0511-01-01,GET_REFCASE=FALSE
* ./cesm_setup
* ./*.build
* cp /glade/work/jiangzhu/data/restart/b.e12.B1850C5CN.f19_g16.iPI.01/* /YOUR_RUN_DIRECTORY/
* ./*.submit
