struct VoronoiFunctions {
    float MIN_EDGE;
    float MAX_EDGE;
    float EDGE_SMOOTHING;

    int OCTAVES;
    float OCTAVE_FREQUENCY_SCALE;
    float OCTAVE_AMPLITUDE_SCALE;

    float3 hash3(float3 p) {
        // procedural white noise	
        return frac(sin(float3(dot(p, float3(127.1, 311.7, 591.1)), dot(p, float3(269.5, 183.3, 113.5)), dot(p, float3(419.2, 371.9, 297.7)))) * 43758.5453);
    }

    float smoothmin(float a, float b, float k) {
        float h = max(k - abs(a - b), 0.0);
        return min(a, b) - h * h * 0.25 / k;
    }

    float4 voronoi(in float3 x) {
        float3 ip = floor(x);
        float3 fp = frac(x);

        //----------------------------------
        // first pass: regular voronoi
        //----------------------------------
        float3 mg, mr;
        float md = 8.0;

        for (int k = -1; k <= 1; k++) {
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float3 g = float3(float(i), float(j), float(k));
                    float3 o = hash3(ip + g);
                    float3 r = g + o - fp;
                    float d = dot(r, r);

                    if (d < md) {
                        md = d;
                        mr = r;
                        mg = g;
                    }
                }
            }
        }

        //----------------------------------
        // second pass: distance to borders
        //----------------------------------
        md = 8;
        for (int k = -2; k <= 2; k++) {
            for (int j = -2; j <= 2; j++) {
                for (int i = -2; i <= 2; i++) {
                    float3 g = mg + float3(float(i), float(j), float(k));
                    float3 o = hash3(ip + g);
                    float3 r = g + o - fp;
                    if (dot(mr - r, mr - r) > 0.00001)
                        md = smoothmin(md, dot(.5 * (mr + r), normalize(r - mr)), EDGE_SMOOTHING);
                }
            }
        }
        return float4(md, mr);
    }

    float4 voronoiFBM(float3 samplePosition, int octaves, float frequencyScale, float contribution) {
        float4 totalValue = float4(0.0, 0.0, 0.0, 0.0);
        float maxValue = 0.0;
        float amplitude = 1.0;

        for (int i = 0; i < octaves; i++) {
            float3 randomOffset = hash3(float3(float(i), float(i) * 1.3, float(i) * 1.7));
            float3 offsetPosition = samplePosition + randomOffset * frequencyScale * (1.0 / amplitude);
            float4 v = voronoi(offsetPosition);
            totalValue += v * amplitude;
            maxValue += amplitude;
            amplitude *= contribution;
            samplePosition *= frequencyScale;
        }

        return totalValue / maxValue;
    }

    float4 edgeVoronoi(float3 fragCoord) {
        float4 fragColor = float4(0, 0, 0, 0);
        float3 p = fragCoord;
        float4 c = voronoi(p * 8.0);
        float edgeMask = lerp(1.0, 0.0, smoothstep(MIN_EDGE, MAX_EDGE, c.x));
        float distanceMask = 1 - saturate(lerp(1.0, 0.0, c.x));
        return float4(edgeMask, distanceMask, 0, 0);
    }

    float4 edgeVoronoiFBM(float3 fragCoord) {
        float4 fragColor = float4(0, 0, 0, 0);
        float3 p = fragCoord;
        float4 c = voronoiFBM(p * 8.0, OCTAVES, OCTAVE_FREQUENCY_SCALE, OCTAVE_AMPLITUDE_SCALE);
        float edgeMask = lerp(1.0, 0.0, smoothstep(MIN_EDGE, MAX_EDGE, c.x));
        float distanceMask = 1 - saturate(lerp(1.0, 0.0, c.x));
        return float4(edgeMask, distanceMask, 0, 0);
    }
};


VoronoiFunctions vf;
vf.MIN_EDGE = EdgeMin;
vf.MAX_EDGE = EdgeMax;
vf.EDGE_SMOOTHING = max(EdgeRounding,.000001);
vf.OCTAVES = Octaves;
vf.OCTAVE_FREQUENCY_SCALE = OctaveFrequencyScale;
vf.OCTAVE_AMPLITUDE_SCALE = OctaveAmplitudeScale;


float3 scaledPosition = WorldPosition/Radius * Frequency;

return vf.edgeVoronoiFBM(float3(scaledPosition));