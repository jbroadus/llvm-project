//===--- TargetRegistry.cpp - Target registration -------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "llvm/Module.h"
#include "llvm/Target/TargetRegistry.h"
#include "llvm/System/Host.h"
#include <cassert>
using namespace llvm;

// Clients are responsible for avoid race conditions in registration.
static Target *FirstTarget = 0;

TargetRegistry::iterator TargetRegistry::begin() {
  return iterator(FirstTarget);
}

const Target *TargetRegistry::lookupTarget(const std::string &TT,
                                           bool FallbackToHost,
                                           bool RequireJIT,
                                           std::string &Error) {
  // Provide special warning when no targets are initialized.
  if (begin() == end()) {
    Error = "Unable to find target for this triple (no targets are registered)";
    return 0;
  }
  const Target *Best = 0, *EquallyBest = 0;
  unsigned BestQuality = 0;
  for (iterator it = begin(), ie = end(); it != ie; ++it) {
    if (RequireJIT && !it->hasJIT())
      continue;

    if (unsigned Qual = it->TripleMatchQualityFn(TT)) {
      if (!Best || Qual > BestQuality) {
        Best = &*it;
        EquallyBest = 0;
        BestQuality = Qual;
      } else if (Qual == BestQuality)
        EquallyBest = &*it;
    }
  }

  // FIXME: Hack. If we only have an extremely weak match and the client
  // requested to fall back to the host, then ignore it and try again.
  if (BestQuality == 1 && FallbackToHost)
    Best = 0;

  // Fallback to the host triple if we didn't find anything.
  if (!Best && FallbackToHost)
    return lookupTarget(sys::getHostTriple(), false, RequireJIT, Error);

  if (!Best) {
    Error = "No available targets are compatible with this triple";
    return 0;
  }

  // Otherwise, take the best target, but make sure we don't have two equally
  // good best targets.
  if (EquallyBest) {
    Error = std::string("Cannot choose between targets \"") +
      Best->Name  + "\" and \"" + EquallyBest->Name + "\"";
    return 0;
  }

  return Best;
}

void TargetRegistry::RegisterTarget(Target &T,
                                    const char *Name,
                                    const char *ShortDesc,
                                    Target::TripleMatchQualityFnTy TQualityFn,
                                    bool HasJIT) {
  assert(Name && ShortDesc && TQualityFn &&
         "Missing required target information!");

  // Check if this target has already been initialized, we allow this as a
  // convenience to some clients.
  if (T.Name)
    return;
         
  // Add to the list of targets.
  T.Next = FirstTarget;
  FirstTarget = &T;

  T.Name = Name;
  T.ShortDesc = ShortDesc;
  T.TripleMatchQualityFn = TQualityFn;
  T.HasJIT = HasJIT;
}

