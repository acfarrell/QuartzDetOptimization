#include<iostream>
#include<fstream>
#include <vector>
#include "TFile.h"
#include "TMath.h"
#include "TTree.h"
#include "TH1.h"
#include "TF1.h"

using namespace std;

double fit_low = 0;
double fit_high = 220;

double sig_low = 0;
double sig_high = 100;

//Sub functions
static const double degtorad = TMath::Pi()/180.;                                                              

static const double twopi = 2*TMath::Pi();                                                                    

double langaufunc(double *x, double *par);

void get_pe(){

  TFile *root_file = TFile::Open("ROOTFILE");
  if (!root_file){
    cerr << "Cannot open file" << endl;
    exit(1);
  }
  TTree *T;
  root_file->GetObject("T",T);
  if (!T){
    cerr << "Cannot find TTree" << endl;
    exit(1);
  }

  int entries = T->GetEntries();
  vector<remollGenericDetectorHit_t>* Hit = new vector<remollGenericDetectorHit_t>;

  if (T->GetBranch("hit"))
    T->SetBranchAddress("hit",&Hit);
  else{
    cerr << "Couldn't find branch 'hit' " << endl;
    exit(1);
  }

  TH1F *h_npe=new TH1F("npe","number of p.e",120,0,120);

  int bins[10000] = {0};
  int sum = 0;
  for(long i = 0; i < entries; i++){ //loop events
    T->GetEntry(i);

    double npe = 0.0;

    for(size_t j = 0; j < Hit->size(); j++){ //loop hits
      remollGenericDetectorHit_t hit = Hit->at(j);

      if(hit.det == DET_ID){  //if this hit is optical photon, and it's hit on the cathode
        npe++;
        sum++;
      }
    }
    bins[i] = npe;
  }

  cout<<sum<<endl;
  for(int k = 0; k < entries; k++){
    h_npe->Fill(bins[k]);
  }
  TF1 *fit_sig = new TF1("fit_sig","gaus",sig_low,sig_high);//initial fit for langau input
  TF1 *fit_func = new TF1("fit_func",langaufunc,fit_low,fit_high,4);//4 parameters
  fit_func->SetLineColor(2);
  fit_func->SetNpx(2000);

  double par1[4] = {0};
  double back1[10] = {0};

  h_npe->Fit(fit_sig,"R","",sig_low,sig_high);
  fit_sig->GetParameters(back1);
  par1[0] = back1[0];
  par1[1] = back1[1];
  par1[2] = back1[2]/2.0;
  par1[3] = back1[2]/2.0;

  fit_func->SetParameters(par1);
  fit_func->SetParNames("Signal Constant","MPV", "sigma_l", "sigma_g");
  h_npe->GetXaxis()->SetRangeUser(fit_low,fit_high);
  h_npe->Fit(fit_func,"R","",fit_low,fit_high);
  gStyle->SetOptFit(1);
  h_npe->SetTitle("PE Yield for Moller Detector;PE;Yield");
  h_npe->Draw();

  // Write MPV to csv file
  ofstream output;
  output.open("yield.csv",std::ofstream::app);
  if (!output.is_open()){
    cerr<<"CSV file not found!" << endl;
    exit(2);
  }

  output << fit_func->GetParameter(1) << "\n";
  output.close();
}

//Fitting function
//Landau convolution with Gaussian
double langaufunc(double *x, double *par){
  double n_steps = 1000;
  double cl = 5; //integral range: +/- 5 sigma of gaussian, convolution is from +/- inf

  double x_low = x[0] -cl*par[3];
  double x_high = x[0] + cl*par[3];
  double step_len = (x_high - x_low)/n_steps;

  //convolution of Landau and Gaussian by sum
  double fland,fgaus,sum = 0;
  for(int i = 1; i<=n_steps;i++){
    double tmp = x_low+(i-0.5)*step_len;
    fland= TMath::Landau(tmp,par[1],par[2],kTRUE);//normalized Landau
    fgaus = TMath::Gaus(x[0],tmp,par[3],kTRUE);//normalized Gaussian
    sum+=fland*fgaus*step_len;
  }
  return(par[0]*sum);
}
