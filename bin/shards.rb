files = Dir.glob("app/models/**/*.rb", base: "/workspace/fizzy").sort
bins = Array.new(4) { [] }; sizes = [0] * 4
files.sort_by { -File.size(File.join("/workspace/fizzy", _1)) }.each { |f| i = sizes.index(sizes.min); bins[i] << f; sizes[i] += File.size(File.join("/workspace/fizzy", f)) }
bins.each_with_index { |b, i| File.write("/workspace/shard#{i + 1}.files", b.sort.join("\n")) }
p bins.map(&:size), sizes
