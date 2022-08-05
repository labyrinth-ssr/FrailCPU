#include <iostream>
#include <string> // Header file needed to use string objects
#include <fstream>
using namespace std;

int main()
{
    ifstream fp1("golden_dhry.txt"); 
    ifstream fp2("dhry_wrong.txt"); 
    string line1,line2;
    int cnt=1;
    while(1){
        getline(fp1,line1);
        getline(fp2,line2);
        // cout<<line1.substr(2,8);


        if (line1!=line2 && line1.substr(2,8)!="9fc0070c" && line1.substr(2,8)!="9fc019c4" &&line1.substr(2,8)!="9fc019d4" &&line1.substr(2,8)!="9fc019f0" &&line1.substr(2,8)!="9fc01a00" &&line1.substr(2,8)!="9fc01a1c" &&line1.substr(2,8)!="9fc01a4c"&&line1.substr(2,8)!="9fc019e0"){
            cout<<"diff: line"<<cnt<<"\nline correct:"<<line1<<"\nline wrong:"<<line2<<endl;
            break;
        }
        cnt++;
    }
    // infile1.open("dhrystone.txt"); 
    
    return 0;
}

// 9fc0070c
// 9fc019c4
// 9fc019d4
// 9fc019f0
// 9fc01a00
// 9fc01a1c
// 9fc01a4c