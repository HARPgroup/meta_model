# Import the pytest package
import pytest
import pandas as pd
import numpy as np

scenario = "hsp2_2022"
seg = "PS2_6730_6660"
CBP_EXPORT_DIR = "/media/model/p6/out"

# use a fixture to set up the environment (i.e. get the data needed to run the test)
# once you define a fixture it can be used by any function or other fixture (by passing it as a named argument)
@pytest.fixture
def hydr_csv():
    hydrd_wy = "{}/river/{}/hydr/{}_hydrd_wy.csv".format(CBP_EXPORT_DIR, scenario, seg)
    hydrd_wy_df = pd.read_csv(hydrd_wy)
    column_names = list(hydrd_wy_df.columns.values)
    # print("column names:", column_names)
    # print(len(hydrd_wy_df.index))
    return hydrd_wy_df

# define the test
def test_for_positive_qout(hydr_csv):
    # retrieve or calculate the value to be tested 
    #qout = -15
    hydrd_wy_df = hydr_csv
    qout = np.average(hydrd_wy_df["Qout"])
    
    # assert statement  
    assert qout > 0 

def test_for_positive_withdrawal(hydr_csv):
    wd_mgd = np.average(hydr_csv["wd_mgd"])
    assert wd_mgd > 0

def test_for_number_of_records(hydr_csv):
    numrecs = len(hydr_csv["index"])
    # print(numrecs)
    # ideally this would compare against the expected number of timesteps
    assert numrecs > 0

def test_water_balance(hydr_csv):
    Qbaseline_sum = np.sum(hydr_csv["Qbaseline"])
    Qout_sum = np.sum(hydr_csv["Qout"])
    # ps_mgd_sum = np.sum(hydr_csv["ps_mgd"])
    # wd_mgd_sum = np.sum(hydr_csv["wd_mgd"])
    # print(Qbaseline_sum)
    # print(Qout_sum)
    # print(Qbaseline_sum + ps_mgd_sum - wd_mgd_sum)

    assert Qbaseline_sum < Qout_sum