#
# Example R program
#

library(IsoSpecR)

X = IsoSpecify(molecule=c(C=254,H=377,N=65,O=75,S=6),
         stopCondition=.9999,
               showCounts=TRUE)
print(X)
