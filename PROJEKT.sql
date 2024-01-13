-- DATABAZE
USE data_academy_2023_12_06;

-- HLAVNI TABULKY CENY A MZDY
SELECT * FROM czechia_price;
SELECT * FROM czechia_price_category;

SELECT * FROM czechia_payroll;
SELECT * FROM czechia_payroll_calculation;
SELECT * FROM czechia_payroll_industry_branch;
SELECT * FROM czechia_payroll_unit;
SELECT * FROM czechia_payroll_value_type;

-- CISLENIKY LOKALIZACE
SELECT * FROM czechia_region;
SELECT * FROM czechia_district;

-- DODATKOVE INFO O ZEMICH
SELECT * FROM countries;
SELECT * FROM economies;

/* VYZKUMNE OTAZKY
 *  1) Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
 *  2) Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?
 *  3) Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
 *  4) Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
 *  5) Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na 
 * 	   cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?
*/ 
-- ad 1)

CREATE OR REPLACE VIEW v_js_prumerne_mzdy_po_odvetvich_a_letech AS
SELECT  cpib.name AS Odvetvi
	,cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
JOIN czechia_payroll_industry_branch AS cpib 
	ON cp.industry_branch_code = cpib.code
WHERE cp.value > 4000 -- vyssi nez prumerna mzda v roce 2000, odstraneni nesmyslu
-- cp.calculation_code = 200
AND cp.value IS NOT NULL
GROUP BY cpib.name, cp.payroll_year ;

DESCRIBE v_js_prumerne_mzdy_po_odvetvich_a_letech;

SELECT
	 Odvetvi,
	CASE
	WHEN MIN(Mzda)-MAX(Mzda) >0
		THEN 'KLESÁ'
		ELSE 'STOUPÁ'
		END AS 'Trend mezd'
FROM v_js_prumerne_mzdy_po_odvetvich_a_letech 
GROUP BY Odvetvi;




-- ad 2)
SELECT * 
FROM czechia_price
WHERE DATE_FORMAT (date_to, '%Y') ;

-- CENY PORDUKTŮ V MIN MAX LETECH Z CENÍKU
SELECT 
	  cpc.name
	  ,DATE_FORMAT (cp.date_to, '%Y') AS Rok
	 ,ROUND(AVG(cp.value),2) AS Cena
--	 ,cp.region_code 
--	 , DATE_FORMAT (date_from, '%Y-%m-%d') 
--	 , DATE_FORMAT (date_to, '%Y-%m-%d') 
FROM czechia_price cp 
JOIN czechia_price_category cpc ON cp.category_code = cpc.code
WHERE (cpc.code = 111301  OR cpc.code = 114201)
AND DATE_FORMAT (cp.date_to, '%Y') = 
	(SELECT DATE_FORMAT (MIN(cp.date_to), '%Y') FROM  czechia_price cp )
GROUP BY cpc.name, DATE_FORMAT (date_to, '%Y')
UNION 
SELECT 
	  cpc.name
	  ,DATE_FORMAT (cp.date_to, '%Y') AS Rok
	 ,ROUND(AVG(cp.value),2) AS Cena
--	 ,cp.region_code 
--	 , DATE_FORMAT (date_from, '%Y-%m-%d') 
--	 , DATE_FORMAT (date_to, '%Y-%m-%d') 
FROM czechia_price cp 
JOIN czechia_price_category cpc ON cp.category_code = cpc.code
WHERE (cpc.code = 111301  OR cpc.code = 114201)
AND DATE_FORMAT (cp.date_to, '%Y') = 
	(SELECT DATE_FORMAT (MAX(cp.date_to), '%Y') FROM  czechia_price cp )
GROUP BY cpc.name, DATE_FORMAT (date_to, '%Y')
-- ORDER BY cpc.name, cp.date_to
;

-- PRUMERNE MZDY PO LETECH
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
JOIN czechia_payroll_industry_branch AS cpib 
	ON cp.industry_branch_code = cpib.code
WHERE cp.value > 4000 -- vyssi nez prumerna mzda v roce 2000, odstraneni nesmyslu
-- cp.calculation_code = 200
AND cp.value IS NOT NULL
GROUP BY  cp.payroll_year ;

-- ROKY OBSAŽENÉ V CENÍKU
SELECT 
DISTINCT DATE_FORMAT (cp.date_to, '%Y') AS Rok 
FROM czechia_price cp ;

-- ROKY OBSAŽENÉ V MZDOVÉ LISTINĚ
SELECT 
DISTINCT cp.payroll_year AS Rok
FROM czechia_payroll AS cp;

-- PRŮNIK MNOŽIN LET V MZDOVÉ LISTINĚ & V CENÍKU
SELECT 
DISTINCT DATE_FORMAT (cp.date_to, '%Y') AS Rok 
FROM czechia_price cp 
INTERSECT
SELECT 
DISTINCT cp.payroll_year AS Rok
FROM czechia_payroll AS cp;

-- tvorba temp tabulky roky prunik

CREATE OR REPLACE VIEW v_js_temp_roky_prunik AS
SELECT
DISTINCT DATE_FORMAT (cp.date_to, '%Y') AS Rok 
FROM czechia_price cp 
INTERSECT
SELECT 
DISTINCT cp.payroll_year AS Rok
FROM czechia_payroll AS cp;

SELECT MIN(Rok) FROM v_js_temp_roky_prunik;

--  MZDA V MIN A MAX ROCE PRŮNIKU 
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
JOIN czechia_payroll_industry_branch AS cpib 
	ON cp.industry_branch_code = cpib.code
WHERE cp.value > 4000 
AND cp.value IS NOT NULL
AND cp.payroll_year = (SELECT MIN(Rok) FROM v_js_temp_roky_prunik)
GROUP BY  cp.payroll_year 
UNION 
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
JOIN czechia_payroll_industry_branch AS cpib 
	ON cp.industry_branch_code = cpib.code
WHERE cp.value > 4000 
AND cp.value IS NOT NULL
AND cp.payroll_year = (SELECT MAX(Rok) FROM v_js_temp_roky_prunik)
GROUP BY  cp.payroll_year 
;



-- CENY CHLEBA A MLEKA V NEJNIŽŠÍM SLEDOVANÉM ROCE V OBOU SEZNAMECH (PRŮNIK)
SELECT 
	  cpc.name
	  ,DATE_FORMAT (cp.date_to, '%Y') AS Rok
	 ,ROUND(AVG(cp.value),2) AS Cena
FROM czechia_price cp 
JOIN czechia_price_category cpc ON cp.category_code = cpc.code
WHERE (cpc.code = 111301  OR cpc.code = 114201)
AND DATE_FORMAT (cp.date_to, '%Y') = 
	( SELECT MIN(Rok) FROM v_js_temp_roky_prunik )
	-- SELECT DATE_FORMAT (MIN(cp.date_to), '%Y') FROM  czechia_price cp 
GROUP BY cpc.name, DATE_FORMAT (date_to, '%Y')
UNION 
SELECT 
	  cpc.name
	  ,DATE_FORMAT (cp.date_to, '%Y') AS Rok
	 ,ROUND(AVG(cp.value),2) AS Cena
FROM czechia_price cp 
JOIN czechia_price_category cpc ON cp.category_code = cpc.code
WHERE (cpc.code = 111301  OR cpc.code = 114201)
AND DATE_FORMAT (cp.date_to, '%Y') = 
	( SELECT MAX(Rok) FROM v_js_temp_roky_prunik )
GROUP BY cpc.name, DATE_FORMAT (date_to, '%Y');

-- TVORBA VIEW PRUMERNE MZDY V MINMAX LETECH
CREATE OR REPLACE VIEW v_js_prum_mzdy_v_minmax_letech AS 
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
JOIN czechia_payroll_industry_branch AS cpib 
	ON cp.industry_branch_code = cpib.code
WHERE cp.value > 4000 
AND cp.value IS NOT NULL
AND cp.payroll_year = (SELECT MIN(Rok) FROM v_js_temp_roky_prunik)
GROUP BY  cp.payroll_year 
UNION 
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
JOIN czechia_payroll_industry_branch AS cpib 
	ON cp.industry_branch_code = cpib.code
WHERE cp.value > 4000 
AND cp.value IS NOT NULL
AND cp.payroll_year = (SELECT MAX(Rok) FROM v_js_temp_roky_prunik)
GROUP BY  cp.payroll_year 
;

-- KOLIK SI KOUPÍM CHLEBA A MLÉKA ZA PRŮMĚRNOU MZDU V MIN A MAX ROCÍCH

SELECT 
	  cpc.name AS Produkt
	  ,DATE_FORMAT (cp.date_to, '%Y') AS Rok
	 ,ROUND(AVG(cp.value),2) AS Cena
	 ,Mzda
	 ,ROUND(Mzda/ROUND(AVG(cp.value),2),0) AS Jednotek_za_Mzdu
FROM czechia_price cp 
JOIN czechia_price_category cpc ON cp.category_code = cpc.code
JOIN v_js_prum_mzdy_v_minmax_letech pm ON  DATE_FORMAT (cp.date_to, '%Y') = Rok
WHERE (cpc.code = 111301  OR cpc.code = 114201)
AND DATE_FORMAT (cp.date_to, '%Y') = 
	( SELECT MIN(Rok) FROM v_js_temp_roky_prunik )
	-- SELECT DATE_FORMAT (MIN(cp.date_to), '%Y') FROM  czechia_price cp 
GROUP BY cpc.name, DATE_FORMAT (date_to, '%Y')
UNION 
SELECT 
	  cpc.name
	  ,DATE_FORMAT (cp.date_to, '%Y') AS Rok
	 ,ROUND(AVG(cp.value),2) AS Cena
	 ,Mzda
	 ,ROUND(Mzda/ROUND(AVG(cp.value),2),0) AS Jednotek_za_Mzdu
FROM czechia_price cp 
JOIN czechia_price_category cpc ON cp.category_code = cpc.code
JOIN v_js_prum_mzdy_v_minmax_letech pm ON  DATE_FORMAT (cp.date_to, '%Y') = Rok
WHERE (cpc.code = 111301  OR cpc.code = 114201)
AND DATE_FORMAT (cp.date_to, '%Y') = 
	( SELECT MAX(Rok) FROM v_js_temp_roky_prunik )
GROUP BY cpc.name, DATE_FORMAT (date_to, '%Y');


-- Ad 3) Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?


SELECT 
	 cpc.name AS Produkt
	,AVG(cp.value) AS Cena1 
	,cp.date_from AS Datum1
	,NULL AS Cena2
	,NULL AS Datum2
FROM czechia_price cp
JOIN czechia_price_category cpc  ON cp.category_code = cpc.code 
WHERE cp.date_to =  (SELECT MIN(cp.date_to) FROM  czechia_price cp )
GROUP BY cpc.name
;

SELECT 
	 cpc.name AS Produkt
	,NULL AS Cena1
	,NULL AS Datum1
	,AVG(cp.value) AS Cena2
	,cp.date_from AS Datum2
FROM czechia_price cp
JOIN czechia_price_category cpc  ON cp.category_code = cpc.code 
WHERE cp.date_to =  (SELECT MAX (cp.date_to) FROM  czechia_price cp )
GROUP BY cpc.name
;

CREATE OR REPLACE VIEW v_js_ceny1 AS
SELECT 
	 cpc.name AS Produkt
	,AVG(cp.value) AS Cena1 
	,cp.date_from AS Datum1
	,NULL AS Cena2
	,NULL AS Datum2
FROM czechia_price cp
JOIN czechia_price_category cpc  ON cp.category_code = cpc.code 
WHERE cp.date_to =  (SELECT MIN(cp.date_to) FROM  czechia_price cp )
GROUP BY cpc.name;

CREATE OR REPLACE VIEW v_js_ceny2 AS
SELECT 
	 cpc.name AS Produkt
	,NULL AS Cena1
	,NULL AS Datum1
	,AVG(cp.value) AS Cena2
	,cp.date_from AS Datum2
FROM czechia_price cp
JOIN czechia_price_category cpc  ON cp.category_code = cpc.code 
WHERE cp.date_to =  (SELECT MAX (cp.date_to) FROM  czechia_price cp )
GROUP BY cpc.name
;

SELECT 
	 cpc.name AS Produkt
	,ROUND(AVG(cp.value),2) AS Cena1
	,DATE_FORMAT(cp.date_from,'%Y %m %d') AS Datum1
	,ROUND(Cena2,2) AS Cena2
	,DATE_FORMAT( Datum2,'%Y %m %d') as Datum2
	,ROUND(((Cena2-AVG(cp.value))/AVG(cp.value))*100,2) '%Změny total'
	,(POWER((Cena2/AVG(cp.value)),(1/(DATE_FORMAT(Datum2,'%Y')-DATE_FORMAT(cp.date_from,'%Y'))))-1)*100 AS 'Mezirocni % narust'
FROM czechia_price cp
JOIN czechia_price_category cpc  ON cp.category_code = cpc.code 
JOIN v_js_ceny2 c2 ON cpc.name = Produkt
WHERE cp.date_to =  (SELECT MIN(cp.date_to) FROM  czechia_price cp )
GROUP BY cpc.name
ORDER BY (POWER((Cena2/AVG(cp.value)),(1/(DATE_FORMAT(Datum2,'%Y')-DATE_FORMAT(cp.date_from,'%Y'))))-1)*100;

-- Ad 4) Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

-- PRUMERNE MZDY PO LETECH
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Mzda
FROM czechia_payroll AS cp
WHERE cp.value > 4000 
AND cp.value IS NOT NULL
GROUP BY  cp.payroll_year ;

CREATE OR REPLACE VIEW v_js_mezitabulka_cenik AS
SELECT 
	cpc.name AS Produkt
	,YEAR (cpr.date_to) AS Rok
	,COUNT(cpc.name) AS Pocet
	,AVG(cpr.value) AS Prum_cena
	,AVG(cpr.value)*COUNT(cpc.name) AS Soucin
FROM czechia_price AS cpr  
JOIN czechia_price_category AS cpc ON cpr.category_code = cpc.code
GROUP BY cpc.name, YEAR(cpr.date_to);

SELECT
	 Produkt	
	,SUM(Pocet)
	,SUM(Soucin)
	,SUM(Soucin)/SUM(Pocet)
FROM v_js_mezitabulka_cenik
GROUP BY  Produkt;


-- TVORBA MEZITABULKY PRUM CEN V LETECH
CREATE OR REPLACE VIEW v_js_prum_ceny_roky AS
SELECT
	Rok	
	,ROUND(SUM(Soucin)/SUM(Pocet),2) AS 'Prum_ceny' 
FROM v_js_mezitabulka_cenik
GROUP BY  Rok;

-- KUMULATIVNÍ SOUČET
SELECT
	 c1.Rok
	,c1.Prum_ceny
	,SUM(c2.Prum_ceny) AS sum
FROM v_js_prum_ceny_roky AS c1
INNER JOIN v_js_prum_ceny_roky AS c2 ON c1.Rok >= c2.Rok
GROUP BY c1.Rok, c1.Prum_ceny
ORDER BY c1.Rok;

-- ITERATIVNÍ PODÍL (%) CEN
SELECT
	 c1.Rok
	,c1.Prum_ceny
	,ROUND(((c2.Prum_ceny/c1.Prum_ceny)-1)*100,2) AS Rozdil
FROM v_js_prum_ceny_roky AS c1
LEFT OUTER JOIN v_js_prum_ceny_roky AS c2 
ON c2.Rok = (c1.Rok+1);

-- ITERATIVNÍ ROZDÍL
SELECT
	 c1.Rok
	,c1.Prum_ceny
	,(c2.Prum_ceny-c1.Prum_ceny) AS Rozdil
FROM v_js_prum_ceny_roky AS c1
LEFT OUTER JOIN v_js_prum_ceny_roky AS c2 
ON c2.Rok = (c1.Rok+1);

-- TVORBA MEZITABULKY PRUM MEZD V LETECH
CREATE OR REPLACE VIEW v_js_prum_mzdy_roky AS
SELECT 
	 cp.payroll_year AS Rok
	,ROUND(AVG(cp.value),0) AS Prum_Mzda
FROM czechia_payroll AS cp
WHERE cp.value > 4000 
AND cp.value IS NOT NULL
GROUP BY  cp.payroll_year ;

-- ITERATIVNÍ PODÍL (%) MEZD
SELECT
	 m1.Rok
	,m1.Prum_Mzda
	,ROUND(((m2.Prum_Mzda/m1.Prum_Mzda)-1)*100,2) AS Rozdil
FROM v_js_prum_mzdy_roky AS m1
LEFT OUTER JOIN v_js_prum_mzdy_roky AS m2 
ON m2.Rok = (m1.Rok+1);

-- ITERATIVNÍ PODÍLY (%) OBA
CREATE OR REPLACE VIEW v_js_iter_podil_ceny AS
SELECT
	 c1.Rok
	,c1.Prum_ceny
	,ROUND(((c2.Prum_ceny/c1.Prum_ceny)-1)*100,2) AS Rozdil
FROM v_js_prum_ceny_roky AS c1
LEFT OUTER JOIN v_js_prum_ceny_roky AS c2 
ON c2.Rok = (c1.Rok+1);

CREATE OR REPLACE VIEW v_js_iter_podil_mzdy AS
SELECT
	 m1.Rok
	,m1.Prum_Mzda
	,ROUND(((m2.Prum_Mzda/m1.Prum_Mzda)-1)*100,2) AS Rozdil
FROM v_js_prum_mzdy_roky AS m1
LEFT OUTER JOIN v_js_prum_mzdy_roky AS m2 
ON m2.Rok = (m1.Rok+1);

SELECT 
	 mzdy.Rok
	,ceny.Rozdil AS ΔCeny
	,mzdy.Rozdil AS ΔMzdy
	,CASE 
		WHEN (ceny.Rozdil IS NULL  OR mzdy.Rozdil IS NULL ) 
		THEN "NEJSOU DATA"
		ELSE ceny.Rozdil-mzdy.Rozdil
	END AS "Růst cen vs růst mezd"
FROM v_js_iter_podil_ceny AS ceny
RIGHT JOIN v_js_iter_podil_mzdy AS mzdy
ON ceny.Rok = mzdy.Rok


/* OPSANO Z INTERNETU
SELECT  f.id, f.length, 
    (f.length - ISNULL(f2.length,0)) AS diff
FROM foo f
LEFT OUTER JOIN foo f2
ON  f2.id = (f.id +1)
--------
select t1.id, t1.SomeNumt, SUM(t2.SomeNumt) as sum
from @t t1
inner join @t t2 on t1.id >= t2.id
group by t1.id, t1.SomeNumt
order by t1.id
 */

