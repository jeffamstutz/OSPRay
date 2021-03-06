// Copyright 2009-2020 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

#include "../bsdfs/Conductor.ih"
#include "../bsdfs/MicrofacetConductor.ih"
#include "Material.ih"
#include "math/spectrum.ih"
#include "texture/TextureParam.ih"

struct Metal
{
  PathTraceMaterial super;

  bool spectral;
  spectrum eta; // index of refraction
  spectrum k; // index of refraction, imaginary part
  vec3f etaRGB; // index of refraction
  vec3f kRGB; // index of refraction, imaginary part
  float roughness; // in [0, 1]; 0==ideally smooth (mirror)
  TextureParam roughnessMap;
};

///////////////////////////////////////////////////////////////////////////////
// Implementation

const varying BSDF *varying Metal_getBSDF(
    const uniform PathTraceMaterial *uniform super,
    uniform ShadingContext *uniform ctx,
    const DifferentialGeometry &dg,
    const Ray &ray,
    const Medium &currentMedium)
{
  const uniform Metal *uniform self = (const uniform Metal *uniform)super;
  varying linear3f *uniform frame = LinearSpace3f_create(ctx, frame(dg.Ns));

  Fresnel *uniform fresnel;
  if (self->spectral)
    fresnel = FresnelConductorSpectral_create(ctx, self->eta, self->k);
  else
    fresnel = FresnelConductorRGBUniform_create(ctx, self->etaRGB, self->kRGB);

  const float roughness = self->roughness * get1f(self->roughnessMap, dg, 1.f);

  if (roughness == 0.0f)
    return Conductor_create(ctx, frame, fresnel);
  else
    return MicrofacetConductor_create(ctx, frame, fresnel, roughness, 0.f);
}

///////////////////////////////////////////////////////////////////////////////
// External API

export void *uniform PathTracer_Metal_set(void *uniform _self,
    const float *uniform eta,
    const float *uniform k,
    const uniform vec3f &etaRGB,
    const uniform vec3f &kRGB,
    uniform float roughness,
    const uniform TextureParam &roughnessMap)
{
  Metal *uniform self = (Metal * uniform) _self;

  self->spectral = eta && k;
  if (self->spectral) {
    // actually could pass "uniform spectrum &", but may have different
    // alignment on C++ side, thus copy element-wise
    for (uniform int l = 0; l < SPECTRUM_SAMPLES; l++) {
      self->eta[l] = eta[l];
      self->k[l] = k[l];
    }
  } else {
    self->etaRGB = etaRGB;
    self->kRGB = kRGB;
  }

  self->roughness = roughness;
  self->roughnessMap = roughnessMap;
}

export void *uniform PathTracer_Metal_create()
{
  Metal *uniform self = uniform new Metal;
  PathTraceMaterial_Constructor(&self->super, Metal_getBSDF);
  uniform vec3f etaRGB = RGB_AL_ETA;
  uniform vec3f kRGB = RGB_AL_K;

  PathTracer_Metal_set(
      self, NULL, NULL, etaRGB, kRGB, 0.1f, make_TextureParam());
  return self;
}
