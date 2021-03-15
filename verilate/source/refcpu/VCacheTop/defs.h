#pragma once

#include "bus.h"

#include "VModel__Syms.h"

using VTopType = VModel_VCacheTop;
using VScope = VModel___024unit;

using CBusReqVType = decltype(VModel::creq);
using CBusWrapper = CBusWrapperGen<CBusReqVType, VTopType>;
