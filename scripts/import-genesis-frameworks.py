import json, pathlib, urllib.request, collections, sys
URL="https://csrc.nist.gov/csrc/media/Projects/cprt/documents/nice/v2-2-0_nf_components.json"
if len(sys.argv)>1:
    data=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
else:
    data=json.loads(pathlib.Path("web/genesis-nice-official.json").read_text(encoding="utf-8"))
assert data["documents"][0]["version"]=="2.2.0"
elements=data["elements"]
index={e["element_identifier"]:e for e in elements}
assert len(index)==len(elements)
counts=collections.Counter(e["element_type"] for e in elements)
assert all(counts[k]==v for k,v in {"category":5,"work_role":42,"task":962,"knowledge":693,"skill":556,"competency_area":11}.items())
assert len(data["relationships"])==5950
links=collections.defaultdict(set)
for rel in data["relationships"]:
    a,b=rel["source_element_identifier"],rel["dest_element_identifier"]
    assert a in index and b in index
    if index[a]["element_type"]=="work_role" and index[b]["element_type"] in ("task","knowledge","skill"):
        links[a].add(b)
assert len(links)==42 and sum(map(len,links.values()))==5410
out=pathlib.Path("web/genesis-nice-official.json")
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(data,ensure_ascii=False,separators=(",",":")),encoding="utf-8")
print("NICE 2.2.0:",dict(counts),"role-TKS links",sum(map(len,links.values())))

ecsf=json.loads(pathlib.Path("web/genesis-ecsf-official.json").read_text(encoding="utf-8"))
assert len(ecsf["roles"])==12
assert len({r["id"] for r in ecsf["roles"]})==12
for r in ecsf["roles"]:
    assert r["title"] and all(r[k] for k in ("tasks","knowledge","skills"))
print("ECSF v1: 12 complete roles")
