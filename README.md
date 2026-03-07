# agentk-edge-tools

Pull network inventory from a site edge computer and merge the results into a single spreadsheet.

---

## Download edge tool

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/edge_site_tool.sh -o edge_site_tool.sh
```

---

## Fix Windows line endings

If the script was edited on a Windows computer.

```bash
sed -i 's/\r$//' edge_site_tool.sh
```

---

## Make script executable

```bash
chmod +x edge_site_tool.sh
```

---

## Run edge tool

```bash
./edge_site_tool.sh
```

---

## Download merge script

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/merge_site_inventory.py -o merge_site_inventory.py
```

---

## Fix Windows line endings for python script

```bash
sed -i 's/\r$//' merge_site_inventory.py
```

---

## Run merge script

```bash
python3 merge_site_inventory.py
```

---

## Windows Line Ending Errors

If a script was edited on Windows you may see:

```
bad interpreter: /bin/bash^M
$'\r': command not found
```

Fix with:

```bash
sed -i 's/\r$//' edge_site_tool.sh
```

or

```bash
sed -i 's/\r$//' merge_site_inventory.py
```

---

## Typical Site Workflow

Run these commands on the edge computer terminal.

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/edge_site_tool.sh -o edge_site_tool.sh
```

```bash
sed -i 's/\r$//' edge_site_tool.sh
```

```bash
chmod +x edge_site_tool.sh
```

```bash
./edge_site_tool.sh
```

```bash
curl -L https://raw.githubusercontent.com/niveek07/agentk-edge-tools/main/merge_site_inventory.py -o merge_site_inventory.py
```

```bash
sed -i 's/\r$//' merge_site_inventory.py
```

```bash
python3 merge_site_inventory.py
```
