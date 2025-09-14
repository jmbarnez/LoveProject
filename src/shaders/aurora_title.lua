local AuroraTitle = {}

-- Creates a shader that renders a moving aurora gradient over text.
-- The shader uses screen-space UVs so it works directly with love.graphics.print/printf.
function AuroraTitle.new()
  local code = [[
    extern number time;

    vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord)
    {
      vec4 texcolor = Texel(tex, texCoord);
      float alpha = texcolor.a * color.a;
      if (alpha <= 0.0) { return vec4(0.0); }

      vec2 uv = screenCoord / love_ScreenSize.xy;
      float t = time;

      // Two moving waves to mix colors for a soft aurora look
      float wave1 = sin(uv.x * 3.2 + t * 0.7) * 0.5 + 0.5;
      float wave2 = sin(uv.x * 7.5 - t * 1.1 + sin(uv.y * 3.0 + t * 0.3)) * 0.5 + 0.5;
      float mixv = clamp(0.25 + wave1 * 0.5 + wave2 * 0.25, 0.0, 1.0);

      // Aurora palette (cyan -> magenta)
      vec3 c1 = vec3(0.00, 0.85, 0.90);
      vec3 c2 = vec3(0.65, 0.30, 0.95);
      vec3 base = mix(c1, c2, mixv);

      // Subtle shimmer that ripples diagonally
      float shimmer = 0.12 * sin((uv.x + uv.y) * 10.0 + t * 2.0);
      base += shimmer;

      // Gentle vertical falloff for readability
      float topFade = smoothstep(0.0, 0.15, uv.y);
      float bottomFade = smoothstep(1.0, 0.85, uv.y);
      base *= (0.9 + 0.1 * topFade * bottomFade);

      return vec4(base, alpha);
    }
  ]]

  local ok, shader = pcall(love.graphics.newShader, code)
  if ok then
    return shader
  else
    return nil
  end
end

return AuroraTitle

