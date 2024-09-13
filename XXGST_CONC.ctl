LOAD DATA
INFILE '&1'
APPEND
INTO TABLE xxapk_sup_site_contact_stg
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
 	OPERATING_UNIT,        	
	SUPPLIER_NUMBER,        
	SITE_NAME,              
	CONT_FIRST_NAME,        
	CONT_MID_NAME,          
	CONT_LAST_NAME,         
	AREA_CODE,              
	PHONE,                  
	EMAIL_ADDRESS,          
	URL,                    
	FAX_AREA_CODE,          
	FAX
)              