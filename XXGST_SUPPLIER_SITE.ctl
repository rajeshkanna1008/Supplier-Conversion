
LOAD DATA
INFILE '&1'
APPEND
INTO TABLE xxap_supplier_sites_stg
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
 	SUPPLIER_NUMBER,        
	SITE_NAME,              
	SITE_NAME_ALT,          
	PURCHASING_SITE_FLAG,   
	RFQ_ONLY_SITE_FLAG,     
	PAY_SITE_FLAG,          
	PRIMARY_PAY_FLAG,       
	ADDRESS_LINE1,          
	ADDRESS_LINE2,          
	ADDRESS_LINE3,          
	ADDRESS_LINE4,          
	CITY,                   
	STATE,                  
	ZIP,                    
	COUNTRY,                
	AREA_CODE,              
	PHONE,                  
	FAX,                    
	FAX_AREA_CODE,          
	TELEX,                  
	EMAIL_ADDRESS,         
	PAYMENT_METHOD,         
	PAY_GROUP,              
	PAYMENT_PRIORITY,       
	PAYMENT_CURRENCY,       
	INVOICE_CURRENCY,      
	TERMS_NAME,             
	INVOICE_AMOUNT_LIMIT,   
	ORG_SHORT_CODE,
	HOLD_UNMATCHED_INVOICES_FLAG ,
	CREATE_DEBIT_MEMO_FLAG ,
	TOLERANCE_NAME,
)              