CREATE OR REPLACE PACKAGE apps.xxap_suppliers_pkg AS
    PROCEDURE xxap_suppliers_conv_main_prc (
        errbuf   OUT  VARCHAR2,
        retcode  OUT  VARCHAR2
    );

END xxap_suppliers_pkg;
/

CREATE OR REPLACE PACKAGE BODY apps.xxap_suppliers_pkg AS
        -- Global Variables
    g_user_id             fnd_user.user_id%TYPE;
    g_login_id            NUMBER(15) := 0;
    g_supplier_found      NUMBER := 0;
    g_site_found          NUMBER := 0;
    g_contact_found       NUMBER := 0;
    g_supplier_processed  NUMBER := 0;
    g_site_processed      NUMBER := 0;
    g_contact_processed   NUMBER := 0;
    g_supplier_rejected   NUMBER := 0;
    g_site_rejected       NUMBER := 0;
    g_contact_rejected    NUMBER := 0;
    -- +===========================================================================+|
    -- | Name :              xxap_sup_site_contact_validate                 |
      -- | Description :       This is the  procedure called by the           |
    -- |                     main procedure to to validate the              |
    -- |                     records in the staging tables                    |
    -- |                                                                    |
    -- | Parameters :        None                                           |
    -- |                                                                    |
    -- | Returns :           none                                     |
    -- |                                                                    |
    -- +====================================================================+
PROCEDURE xxap_sup_sit_con_val_prc AS
-----------------------------1st Cursor  for Supplier  ----------------------------------
    CURSOR lcu_suppliers IS
        SELECT
            xass.rowid rid,
            xass.*
        FROM
            xxap_suppliers_stg xass
        WHERE
            xass.status_flag IS NULL;
-----------------------------2nd Cursor for Sites ----------------------------------
    CURSOR lcu_sites (
            p_vendor_id NUMBER
        ) IS
        SELECT
            xasss.rowid,
            xasss.*
        FROM
            xxap_supplier_sites_stg xasss
        WHERE
            xasss.status_flag IS NULL
            AND xasss.supplier_number = p_vendor_id;
-----------------------------3rd Corsor for Contacts  ----------------------------------
    CURSOR lcu_contacts (
            p_vendor_id         NUMBER,
            p_vendor_site_code  VARCHAR2
        ) IS
        SELECT
            xascs.rowid,
            xascs.*
        FROM
            xxap_sup_site_contact_stg xascs
        WHERE
            xascs.status_flag IS NULL
            AND xascs.supplier_number = p_vendor_id
            AND xascs.site_name = p_vendor_site_code;
  ----------------------------local Variables---------------------------------
        l_user_id               NUMBER(15);
        l_error                 NUMBER := 0;
        l_s_error               NUMBER := 0;
        l_c_error               NUMBER := 0;
        l_site_code             VARCHAR2(100);
        l_lookup_code           VARCHAR2(100);
        l_terms_name            VARCHAR2(100);
        l_site_terms_name       VARCHAR2(100);
        l_site_pay_grp          VARCHAR2(100);
        l_rec_errored_hdr       NUMBER := 0;
        l_rec_errored_sites     NUMBER := 0;
        l_rec_errored_contacts  NUMBER := 0;
        l_sup_err_details       VARCHAR2(4000);
        l_errmsg                VARCHAR2(4000);
        l_dup_count_org_id      NUMBER := 0;
        l_vendor_site_id        VARCHAR2(50);
        l_pay_date              VARCHAR2(50);
        l_terms_id              NUMBER(15) := 0;
        l_sit_err_details       VARCHAR2(3000);
        l_con_err_details       VARCHAR2(3000);
        l_sup_pay_method        ap_suppliers.payment_method_lookup_code%TYPE;
        l_suppliers_error       VARCHAR2(2000);
        l_sites_error           VARCHAR2(2000);
        l_contacts_error        VARCHAR2(2000);
        l_seq                   NUMBER;
        l_payment_currency      VARCHAR2(50);
        l_invoice_currency      VARCHAR2(50);
        l_sit_payment_currency  VARCHAR2(50);
        l_sit_invoice_currency  VARCHAR2(50);
        l_pay_group             VARCHAR2(50);
        l_site_pay_group        VARCHAR2(50);
        l_site_pay_method       ap_suppliers.payment_method_lookup_code%TYPE;
        l_orgid                 hr_operating_units.organization_id%TYPE;
        l_con_orgid             hr_operating_units.organization_id%TYPE;
        l_sit_terms_id          NUMBER(15);
        l_sit_terms_name        VARCHAR2(50);
        l_sit_country_code      VARCHAR2(2);
        ln_tolerance_id         NUMBER;
 --===============================================================================
              -- Create the Error Procedure to  be called in the  Validate Procedure...
PROCEDURE update_error_table (
            p_tablename  VARCHAR2,
            p_error_id   VARCHAR2,
            p_error_des  VARCHAR2
        ) AS
            p_tab  VARCHAR2(100);
            p_err  VARCHAR2(100);
            p_des  VARCHAR2(4000);
        BEGIN
            p_tab := p_tablename;
            p_err := p_error_id;
            p_des := p_error_des;
            INSERT INTO xxap_conv_staging_errors (
                table_name,
                err_creation_date,
                error_identifier,
                error_description
            ) VALUES (
                p_tab,
                sysdate,
                p_err,
                p_des
            );

            COMMIT;
END update_error_table;
        -- end of error updating procedure --
--=========================================================
    BEGIN
        SELECT
            COUNT(*)
        INTO g_supplier_found
        FROM
            xxap_suppliers_stg
        WHERE
            status_flag IS NULL;

        SELECT
            COUNT(*)
        INTO g_site_found
        FROM
            xxap_supplier_sites_stg
        WHERE
            status_flag IS NULL;

        SELECT
            COUNT(*)
        INTO g_contact_found
        FROM
            xxap_sup_site_contact_stg xascs
        WHERE
            status_flag IS NULL;

        dbms_output.put_line('BEFORE SUPPLIER LOOP..');
        g_supplier_processed := 0;
        g_site_processed := 0;
        g_contact_processed := 0;
        g_supplier_rejected := 0;
        g_site_rejected := 0;
        g_contact_rejected := 0;
        FOR sup_rec IN lcu_suppliers LOOP
            l_suppliers_error := NULL;
            l_sup_err_details := NULL;
            l_terms_name := NULL;
            l_invoice_currency := NULL;
            l_payment_currency := NULL;
            l_pay_group := NULL;
            l_sup_pay_method := NULL;
            ln_tolerance_id := NULL;
--****************** Validation Start for Suppliers ***************************
            --==========================================================
                            -- Validation for supplier_number
            --===========================================================
            IF sup_rec.supplier_number IS NULL THEN
                l_suppliers_error := 'Y';
                l_sup_err_details := l_sup_err_details || '\ Supplier_number is NULL';
                fnd_file.put_line(fnd_file.log, l_sup_err_details);
            END IF;
            --==========================================================
                            -- Validation for supplier_name
            --===========================================================
            IF sup_rec.supplier_name IS NULL THEN
                l_suppliers_error := 'Y';
                l_sup_err_details := l_sup_err_details || '\ Supplier_name is NULL';
                fnd_file.put_line(fnd_file.log, l_sup_err_details);
            END IF;
            --==========================================================
                            -- Validation for terms_name
            --===========================================================
            IF sup_rec.terms_name IS NOT NULL THEN
                BEGIN
                    SELECT
                        term_id,
                        name
                    INTO
                        l_terms_id,
                        l_terms_name
                    FROM
                        ap_terms
                    WHERE
                        upper(name) = upper(sup_rec.terms_name);

                EXCEPTION
                    WHEN no_data_found THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\ Term Name -'
                                             || sup_rec.terms_name
                                             || ' does not Exists for supplier '
                                             || sup_rec.supplier_name;

                        fnd_file.put_line(fnd_file.log, l_sup_err_details);
                    WHEN OTHERS THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\ Terms Name Validation failed for  Term Name -'
                                             || sup_rec.terms_name
                                             || ' for supplier '
                                             || sup_rec.supplier_name
                                             || ' Error no-'
                                             || substr(sqlerrm, 1, 100);

                        fnd_file.put_line(fnd_file.log, l_sup_err_details);
                END;
            ELSE
                l_suppliers_error := 'Y';
                l_sup_err_details := l_sup_err_details
                                     || '\  Term Name can not be blank for supplier '
                                     || sup_rec.supplier_name;
                fnd_file.put_line(fnd_file.log, l_sup_err_details);
            END IF;

            IF sup_rec.invoice_currency IS NOT NULL THEN
            --=================================================================
                 -- Validation for supplier invoice currency code
               --==================================================================
                BEGIN
                    SELECT
                        currency_code
                    INTO l_invoice_currency
                    FROM
                        fnd_currencies
                    WHERE
                            upper(currency_code) = upper(sup_rec.invoice_currency)
                        AND enabled_flag = 'Y';

                EXCEPTION
                    WHEN no_data_found THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\
                             Currency Code -'
                                             || sup_rec.invoice_currency
                                             || ' does not Exists for supplier '
                                             || sup_rec.supplier_name;

                    WHEN OTHERS THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\
                            Supplier currency Validation failed for  currency code -'
                                             || sup_rec.invoice_currency
                                             || ' for supplier '
                                             || sup_rec.supplier_name
                                             || ' Error no-'
                                             || substr(sqlerrm, 1, 100);

                END;
            END IF;

            IF sup_rec.payment_currency IS NOT NULL THEN
            --=================================================================
                 -- Validation for supplier payment currency code
               --==================================================================
                BEGIN
                    SELECT
                        currency_code
                    INTO l_payment_currency
                    FROM
                        fnd_currencies
                    WHERE
                            upper(currency_code) = upper(sup_rec.payment_currency)
                        AND enabled_flag = 'Y';

                EXCEPTION
                    WHEN no_data_found THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || ' \ Payment Currency Code -'
                                             || sup_rec.payment_currency
                                             || ' does not Exists for supplier '
                                             || sup_rec.supplier_name;

                    WHEN OTHERS THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\ Supplier Payment currency Validation failed for  currency code -'
                                             || sup_rec.payment_currency
                                             || ' for supplier '
                                             || sup_rec.supplier_name
                                             || ' Error no-'
                                             || substr(sqlerrm, 1, 100);

                END;
            END IF;

            IF sup_rec.pay_group IS NOT NULL THEN
            --=================================================================
                     -- Validation for supplier pay Group
               --==================================================================
                BEGIN
                    SELECT
                        lookup_code
                    INTO l_pay_group
                    FROM
                        fnd_lookup_values
                    WHERE
                            lookup_type = 'PAY GROUP'
                        AND language = 'US'
                        AND upper(meaning) = upper(sup_rec.pay_group);

                EXCEPTION
                    WHEN no_data_found THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || ' \ Pay Group Code -'
                                             || sup_rec.pay_group
                                             || ' does not Exists for supplier '
                                             || sup_rec.supplier_name;

                    WHEN OTHERS THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\ Supplier Pay Group Validation failed for  pay Group -'
                                             || sup_rec.pay_group
                                             || ' for supplier '
                                             || sup_rec.supplier_name
                                             || ' Error no-'
                                             || substr(sqlerrm, 1, 100);

                END;
            END IF;

            IF sup_rec.payment_method IS NOT NULL THEN
                --=================================================================
                     -- Validation for supplier payment method
                   --==================================================================
                BEGIN
                    /*SELECT lookup_code
                    INTO l_sup_pay_method
                    FROM  ap_lookup_codes
                    WHERE lookup_type= 'PAYMENT METHOD'
                    AND UPPER(displayed_field) =  UPPER(sup_rec.payment_method);*/
                    SELECT
                        payment_method_code
                    INTO l_sup_pay_method
                    FROM
                        iby_payment_methods_tl
                    WHERE
                            language = 'US'
                        AND upper(payment_method_name) = upper(sup_rec.payment_method);

                EXCEPTION
                    WHEN no_data_found THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || ' \ '
                                             || 'Payment Method -'
                                             || sup_rec.payment_method
                                             || ' does not Exists for supplier '
                                             || sup_rec.supplier_name;

                    WHEN OTHERS THEN
                        l_suppliers_error := 'Y';
                        l_sup_err_details := l_sup_err_details
                                             || '\ Supplier Payment Method Validation'
                                             || 'failed for Payment Method -'
                                             || sup_rec.payment_method
                                             || ' for supplier '
                                             || sup_rec.supplier_name
                                             || ' Error no-'
                                             || substr(sqlerrm, 1, 100);

                END;
            END IF;

            IF sup_rec.payment_priority IS NOT NULL THEN
                --=================================================================
                     -- Validation for supplier payment priority
                   --==================================================================
                 IF sup_rec.payment_priority < 1 OR sup_rec.payment_priority > 99 THEN
                    l_suppliers_error := 'Y';
                    l_sup_err_details := l_sup_err_details || '\ 
                        payment priority out of valid range 1-99';
                END IF;
            END IF;
        --***************************** Validation End for Suppliers ******************
        -- *** if there is an error in suppliers then update supplier,site and contacts staging tables*****----
            IF nvl(l_suppliers_error, 'N') = 'Y' THEN
                UPDATE xxap_suppliers_stg
                SET
                    status_flag = 'E',
                    error_msg = substr(l_sup_err_details, 1, 1000)
                WHERE
                    ROWID = sup_rec.rid;

                g_supplier_rejected := g_supplier_rejected + 1;
                UPDATE xxap_supplier_sites_stg
                SET
                    status_flag = 'E',
                    error_msg = 'Validation Failed in Suppliers'
                WHERE
                    supplier_number = sup_rec.supplier_number;

                UPDATE xxap_sup_site_contact_stg
                SET
                    status_flag = 'E',
                    error_msg = 'Validation Failed in Suppliers'
                WHERE
                    supplier_number = sup_rec.supplier_number;
                  ---------------Called the Error Procedure to update the Error Table--------
                    update_error_table('XXAP_SUPPLIERS_STG', 'Sup_name:' || sup_rec.supplier_name, substr(l_sup_err_details, 1, 1000));

            ELSE
                UPDATE xxap_suppliers_stg
                SET
                    status_flag = 'V'
                WHERE
                    ROWID = sup_rec.rid;

                g_supplier_processed := g_supplier_processed + 1;
                    --+**************** Validation Start for Sites ****************
            FOR sit_rec IN lcu_sites(sup_rec.supplier_number)
                LOOP
                    l_sites_error := NULL;
                    l_sit_err_details := NULL;
                    l_orgid := NULL;
                    l_sit_terms_id := NULL;
                    l_sit_terms_name := NULL;
                    l_sit_terms_id := NULL;
                    l_sit_terms_name := NULL;
                    l_sit_country_code := NULL;
                    l_sit_invoice_currency := NULL;
                    l_sit_payment_currency := NULL;
                    l_site_pay_group := NULL;
                    l_site_pay_method := NULL;
                    --=======================================================================
                    -- 'Validation Check for operating_unit'
                --=================================================================================
                    IF sit_rec.org_short_code IS NULL THEN
                        l_sites_error := 'Y';
                        l_sit_err_details := l_sit_err_details || '\ operating unit is NULL';
                        fnd_file.put_line(fnd_file.log, 'operating unit is NULL');
                    ELSE
                        BEGIN
                            SELECT
                                organization_id
                            INTO l_orgid
                            FROM
                                hr_operating_units
                            WHERE
                                short_code = sit_rec.org_short_code;

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sit_err_details := l_sit_err_details
                                                     || '\
                                Operating Unit not Defined in sites -'
                                                     || sit_rec.org_short_code
                                                     || ' For the supplier '
                                                     || sup_rec.supplier_name;

                                fnd_file.put_line(fnd_file.log,
                                                 'operating unit not in' || 'hr_operating_units');
                            WHEN OTHERS THEN
                                l_sit_err_details := l_sit_err_details
                                                     || '\ Supplier Site Operating Unit'
                                                     || ' Validation Failed -'
                                                     || sit_rec.org_short_code
                                                     || ' Error No-'
                                                     || substr(sqlerrm, 1, 100)
                                                     || chr(10);

                                fnd_file.put_line(fnd_file.log, 'operating unit other exception');
                        END;
-- fnd_file.put_line(fnd_file.OUTPUT,'Org id  : '||l_orgid);
                   IF l_orgid IS NOT NULL THEN
                            UPDATE xxap_supplier_sites_stg
                            SET
                                org_id = l_orgid
                            WHERE
                                ROWID = sit_rec.rowid;

                            COMMIT;
                        END IF;
                    END IF;
                    --==========================================================
                                -- Validation for site_name
                    --===========================================================
                    IF sit_rec.site_name IS NULL THEN
                        l_sites_error := 'Y';
                        l_sit_err_details := l_sit_err_details || '\
                              Site_name is NULL';
                        fnd_file.put_line(fnd_file.log, l_sit_err_details);
                    END IF;
                --==================================================================
                           -- Duplicate Check for sites
                       --==================================================================
                    BEGIN
                        SELECT
                            COUNT(*)
                        INTO l_dup_count_org_id
                        FROM
                            xxap_supplier_sites_stg
                        WHERE
                                supplier_number = sup_rec.supplier_number
                            AND org_id = l_orgid
                            AND upper(site_name) = upper(sit_rec.site_name);

                        IF l_dup_count_org_id > 1 THEN
                            l_sites_error := 'Y';
                            l_sit_err_details := l_sit_err_details
                                                 || 'duplicate site entry for'
                                                 || sup_rec.supplier_number
                                                 || '/'
                                                 || sit_rec.site_name
                                                 || '/'
                                                 || sit_rec.org_short_code;

                            fnd_file.put_line(fnd_file.log, l_sup_err_details);
                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            l_sites_error := 'Y';
                            l_sit_err_details := 'Duplicate Check Other Excep : ' || sqlerrm;
                            fnd_file.put_line(fnd_file.log, l_sit_err_details);
                    END;
                --==========================================================
                                    -- Validation for site terms_name
                    --===========================================================
                    IF sit_rec.terms_name IS NOT NULL THEN
                        BEGIN
                            SELECT
                                term_id,
                                name
                            INTO
                                l_sit_terms_id,
                                l_sit_terms_name
                            FROM
                                ap_terms
                            WHERE
                                upper(name) = upper(sit_rec.terms_name);

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\'
                                                     || 'terms_name for Suppliers site not Defined For'
                                                     || ' Supplier/Site/Term name--'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.terms_name;

                                fnd_file.put_line(fnd_file.log, l_sit_err_details);
                            WHEN OTHERS THEN
                                l_suppliers_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\ Terms Name Validation failed in Supplier Sites'
                                                     || 'for Supplier/Site/Term name : '
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.terms_name
                                                     || ' Error no -'
                                                     || substr(sqlerrm, 1, 100);

                                fnd_file.put_line(fnd_file.log, l_sit_err_details);
                        END;
                    END IF;
                                    -- Validation for site COUNTRY CODE
                    --===========================================================
                    IF sit_rec.country IS NOT NULL THEN
                        BEGIN
                            SELECT
                                territory_code
                            INTO l_sit_country_code
                            FROM
                                fnd_territories
                            WHERE
                                upper(nls_territory) = upper(sit_rec.country);

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\'
                                                     || 'Country for Suppliers site not Defined --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.country;

                                fnd_file.put_line(fnd_file.log, l_sit_err_details);
                            WHEN OTHERS THEN
                                l_suppliers_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\ Country Exception failed in Supplier Sites'
                                                     || 'for Supplier/Site : '
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.country
                                                     || ' Error no -'
                                                     || substr(sqlerrm, 1, 100);

                                fnd_file.put_line(fnd_file.log, l_sit_err_details);
                        END;
                    END IF;

                IF sit_rec.invoice_currency IS NOT NULL THEN
            --=================================================================
                 -- Validation for site invoice currency code
               --==================================================================
                      BEGIN
                            SELECT
                                currency_code
                            INTO l_sit_invoice_currency
                            FROM
                                fnd_currencies
                            WHERE
                                    upper(currency_code) = upper(sit_rec.invoice_currency)
                                AND enabled_flag = 'Y';

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\ 
                            Invoice Currency  Not Defined for Supplier/Site/currency code : '
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.invoice_currency;

                            WHEN OTHERS THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\ Invoice Currency exception failed for'
                                                     || 'Supplier/Site/currency code : '
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.invoice_currency
                                                     || ' Error code -'
                                                     || substr(sqlerrm, 1, 100);

                        END;
                    END IF;

                    IF sit_rec.payment_currency IS NOT NULL THEN
            --=================================================================
                 -- Validation for site payment currency code
               --==================================================================
                       BEGIN
                            SELECT
                                currency_code
                            INTO l_sit_payment_currency
                            FROM
                                fnd_currencies
                            WHERE
                                    upper(currency_code) = upper(sit_rec.payment_currency)
                                AND enabled_flag = 'Y';

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || ' \ '
                                                     || 'Payment Currency  Not Defined for Supplier/Site/currency code : '
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.payment_currency;

                            WHEN OTHERS THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\ payment Currency exception failed for'
                                                     || 'Supplier/Site/currency code : '
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.payment_currency
                                                     || ' Error code -'
                                                     || substr(sqlerrm, 1, 100);

                        END;
                    END IF;

                    IF sit_rec.pay_group IS NOT NULL THEN
            --=================================================================
                 -- Validation for site pay Group
               --==================================================================
                      BEGIN
                            SELECT
                                lookup_code
                            INTO l_site_pay_group
                            FROM
                                fnd_lookup_values
                            WHERE
                                    lookup_type = 'PAY GROUP'
                                AND language = 'US'
                                AND upper(meaning) = upper(sit_rec.pay_group);

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || ' \ '
                                                     || 'Pay Group Not defined for the supplier/site/pay group --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.pay_group;

                            WHEN OTHERS THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\'
                                                     || 'Pay Group Validation failed for  the supplier/site/pay group --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.pay_group
                                                     || '  -- error code --'
                                                     || substr(sqlerrm, 1, 100);

                        END;
                    END IF;

                    IF sup_rec.payment_method IS NOT NULL THEN
                --=================================================================
                     -- Validation for site payment method
                   --==================================================================
                      BEGIN
                        /*SELECT lookup_code
                              INTO l_site_pay_method
                              FROM  ap_lookup_codes
                             WHERE lookup_type= 'PAYMENT METHOD'
                              AND UPPER(displayed_field) =  UPPER(sit_rec.payment_method);*/
                            SELECT
                                payment_method_code
                            INTO l_sup_pay_method
                            FROM
                                iby_payment_methods_tl
                            WHERE
                                    language = 'US'
                                AND upper(payment_method_name) = upper(sit_rec.payment_method);

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || ' \ '
                                                     || 'Payment Method  Not defined for'
                                                     || ' the supplier/site/payment method --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.payment_method;

                            WHEN OTHERS THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\'
                                                     || 'Pay method validation failed for'
                                                     || '  :supplier/site/payment method --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.payment_method
                                                     || ' Error code-'
                                                     || substr(sqlerrm, 1, 100);

                        END;
                    END IF;

                    IF sit_rec.tolerance_name IS NOT NULL THEN
                --=================================================================
                     -- Validation for supplier tolerance
                   --==================================================================
                       BEGIN
                            SELECT
                                tolerance_id
                            INTO ln_tolerance_id
                            FROM
                                ap_tolerance_templates
                            WHERE
                                upper(tolerance_name) = upper(sit_rec.tolerance_name);

                        EXCEPTION
                            WHEN no_data_found THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || ' \ '
                                                     || 'Tolerance  Not defined for'
                                                     || ' the supplier/site/tolerance --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.tolerance_name;

                            WHEN OTHERS THEN
                                l_sites_error := 'Y';
                                l_sit_err_details := l_sit_err_details
                                                     || '\'
                                                     || 'Tolerance validation failed for'
                                                     || '  :supplier/site/payment method --'
                                                     || sup_rec.supplier_name
                                                     || '/'
                                                     || sit_rec.site_name
                                                     || '/'
                                                     || sit_rec.tolerance_name
                                                     || ' Error code-'
                                                     || substr(sqlerrm, 1, 100);

                        END;

                        IF ln_tolerance_id IS NOT NULL THEN
                            UPDATE xxap_supplier_sites_stg
                            SET
                                tolerance_id = ln_tolerance_id
                            WHERE
                                ROWID = sit_rec.rowid;

                            COMMIT;
                        END IF;

                    END IF;

                    IF sup_rec.payment_priority IS NOT NULL THEN
                --=================================================================
                     -- Validation for supplier payment priority
                   --==================================================================
                    IF sit_rec.payment_priority < 1 OR sit_rec.
                        payment_priority > 99 THEN
                            l_sites_error := 'Y';
                            l_sit_err_details := l_sit_err_details || '\ payment priority out of valid range 1-100';
                        END IF;
                    END IF;
            --+**************** Validation end for Sites ****************
                    IF nvl(l_sites_error, 'N') = 'Y' OR nvl(l_suppliers_error, 'N') = 'Y' THEN
                        UPDATE xxap_supplier_sites_stg
                        SET
                            status_flag = 'E',
                            error_msg = substr(l_sit_err_details, 1, 1000)
                        WHERE--  supplier_number       =sit_rec.supplier_number 
                                                                        ROWID = sit_rec.rowid;

                        g_site_rejected := g_site_rejected + 1;
                        UPDATE xxap_sup_site_contact_stg
                        SET
                            status_flag = 'E',
                            error_msg = 'Validation Failed in Sites'
                        WHERE
                                supplier_number = sit_rec.supplier_number
                            AND site_name = sit_rec.site_name;
                                       ----Called the Error Procedure to update the Error Table--------
                                                            update_error_table('xxap_supplier_sites_stg',
                                          'site_name:' || sit_rec.site_name,
                                          l_sit_err_details);
                    ELSE
                        UPDATE xxap_supplier_sites_stg
                        SET
                            status_flag = 'V',
                            terms_name = l_sit_terms_name,
                            pay_group = l_site_pay_group,
                            payment_method = l_site_pay_method,
                                         --     org_id           = l_orgid,
                                                                          terms_id = l_sit_terms_id,
                            invoice_currency = l_sit_invoice_currency,
                            payment_currency = l_sit_payment_currency,
                            country_code = l_sit_country_code
                        WHERE
                            ROWID = sit_rec.rowid;

                        g_site_processed := g_site_processed + 1;
                        FOR con_rec IN lcu_contacts(sit_rec.supplier_number, sit_rec.site_name) LOOP
                            l_contacts_error := NULL;
                            l_con_err_details := NULL;
                            l_con_orgid := NULL;
                        --+************** Validation Start for contacts **************
                        --=======================================================================
                    -- 'Validation Check for operating_unit'
                --=================================================================================
                           IF con_rec.operating_unit IS NULL THEN
                                l_contacts_error := 'Y';
                                l_con_err_details := l_con_err_details || '\ operating unit is NULL';
                                fnd_file.put_line(fnd_file.log, 'operating unit is NULL');
                            ELSE
                                BEGIN
                                    SELECT
                                        organization_id
                                    INTO l_con_orgid
                                    FROM
                                        hr_operating_units
                                    WHERE
                                        upper(name) = upper(con_rec.operating_unit);

                                EXCEPTION
                                    WHEN no_data_found THEN
                                        l_con_err_details := l_con_err_details
                                                             || '\ Operating Unit not Defined For supplier/Site/operating unit'
                                                             || sup_rec.supplier_name
                                                             || '/'
                                                             || sit_rec.site_name
                                                             || '/'
                                                             || con_rec.operating_unit;

                                        fnd_file.put_line(fnd_file.log, 'operating unit not in' || 'hr_operating_units');
                                    WHEN OTHERS THEN
                                        l_con_err_details := l_con_err_details
                                                             || '\'
                                                             || 'Suplier Site Contact Operating Unit Validation Failed for'
                                                             || 'supplier/Site/Operating Unit --'
                                                             || sup_rec.supplier_name
                                                             || '/'
                                                             || sit_rec.site_name
                                                             || '/'
                                                             || con_rec.operating_unit
                                                             || ' Error Code-'
                                                             || substr(sqlerrm, 1, 100)
                                                             || chr(10);

                                        fnd_file.put_line(fnd_file.log, 'operating unit other exception');
                                END;

                                IF l_con_orgid IS NOT NULL THEN
                                    UPDATE xxap_sup_site_contact_stg
                                    SET
                                        org_id = l_con_orgid
                                    WHERE
                                        ROWID = con_rec.rowid;

                                    COMMIT;
                                END IF;

                            END IF;
                        --================================================
                                  --  Check the fIRST Name for Supplier
                        --=====================================================
                           /*BEGIN
                               IF con_rec.cont_FIRST_name IS NULL  THEN
                                  l_contacts_error:='Y';
                                  l_con_err_details :=  'Contact First Name'
                                    || 'Cannot be null For the supplier/Site '
                                    ||sup_rec.supplier_name||'/'
                                    ||sit_rec.site_name;
                             END IF;
                           END;*/
                        --================================================
                                  --  Check the Last Name for Supplier
                        --=====================================================
                           /*BEGIN
                                IF con_rec.cont_last_name IS NULL  THEN
                                  l_contacts_error:='Y';
                                  l_con_err_details := 'Contact Last Name'
                                    || 'Cannot be null for the supplier/Site/First name'
                                    ||sup_rec.supplier_name||'/'||sit_rec.site_name
                                    ||'/'||con_rec.cont_FIRST_name;
                         END IF;
                               END;*/
                        --************Validation End for Contacts**************
                        IF nvl(l_contacts_error, 'N') = 'Y' OR nvl(l_sites_error, 'N') = 'Y'
                            OR nvl(l_suppliers_error, 'N') = 'Y' THEN
                                UPDATE xxap_sup_site_contact_stg
                                SET
                                    status_flag = 'E',
                                    error_msg = substr(l_con_err_details, 1, 1000)
                                WHERE
                                    supplier_number = con_rec.supplier_number;
                                          -- rowid            = con_rec.rowid;
                                                                        g_contact_rejected :=
                                g_contact_rejected + 1;
                                UPDATE xxap_suppliers_stg
                                SET
                                    status_flag = 'E',
                                    error_msg = 'Validation Failed in Contacts'
                                WHERE
                                    supplier_number = con_rec.supplier_number;

                                UPDATE xxap_supplier_sites_stg
                                SET
                                    status_flag = 'E',
                                    error_msg = 'Validation Failed in Contacts'
                                WHERE
                                    supplier_number = con_rec.supplier_number;
                                              --site_name= con_rec.site_name;
                                       ----Called the Error Procedure to update the Error Table--------
                                                                                 update_error_table('xxap_sup_site_contact_stg',
                                                  'name:'
                                                  || con_rec.cont_first_name
                                                  || ','
                                                  || con_rec.cont_last_name,
                                                  l_sit_err_details);

                            ELSE
                                UPDATE xxap_sup_site_contact_stg
                                SET
                                    status_flag = 'V',
                                    org_id = l_con_orgid
                                WHERE
                                    ROWID = con_rec.rowid;

                                g_contact_processed := g_contact_processed + 1;
                            END IF;

                        END LOOP;  -- LOOP FOR CONTACTS
                                            END IF;-- if for checking sites errors
                                END LOOP;  --for sites loop
        /* The following code changes the status of the supplier record 
            if there exists even a single site record with error */
                        END IF;-- if for checking supplier errors
                        UPDATE xxap_suppliers_stg
            SET
                status_flag = 'E',
                error_msg = 'one or more invalid sites found'
            WHERE
                    ROWID = sup_rec.rid
                AND EXISTS (
                    SELECT
                        'X'
                    FROM
                        xxap_supplier_sites_stg
                    WHERE
                            supplier_number = sup_rec.supplier_number
                        AND status_flag = 'E'
                );

        END LOOP; -- for suppliers loop
        END xxap_sup_sit_con_val_prc;
    -------- end of  validation procedure ------
      PROCEDURE xxap_sup_site_con_insert_prc AS
    -- +====================================================================+
    -- | Name :              xxap_sup_site_con_insert                       |
      -- | Description :       This is the  procedure called by the           |
    -- |                     main procedure to insert  the records into the |
    -- |                     interface  tables after validation             |
    -- |                                                                    |
    -- | Parameters :        None                                           |
    -- |                                                                    |
    -- | Returns :           None                                           |
    -- |                                                                    |
    -- +====================================================================+
                  g_user_id          NUMBER := fnd_global.
        user_id;
        l_sup_err_details  VARCHAR2(2000);
       ------------------1st Cursor  for suppliers --------------------
                CURSOR lcu_ins_suppliers IS
        SELECT
            sup.rowid,
            sup.*
        FROM
            xxap_suppliers_stg sup
        WHERE
            sup.status_flag = 'V';
    -------2nd Corsor for sites ---------------------------
               CURSOR lcu_ins_sites (
            p_vendor_id NUMBER
        ) IS
        SELECT
            sit.rowid,
            sit.*
        FROM
            xxap_supplier_sites_stg sit
        WHERE
                sit.status_flag = 'V'
            AND sit.supplier_number = p_vendor_id;
       ------------------------3rd Corsor for contacts -----------------
               CURSOR lcu_ins_contacts (
            p_vendor_id         NUMBER,
            p_vendor_site_code  VARCHAR2
        ) IS
        SELECT
            con.rowid,
            con.*
        FROM
            xxap_sup_site_contact_stg con
        WHERE
                con.status_flag = 'V'
            AND con.site_name = p_vendor_site_code
            AND con.supplier_number = p_vendor_id;
       ------------------------------Define Variables--------------------
                l_ins_sup_error    VARCHAR2(2000);
        l_ins_sit_error    VARCHAR2(2000);
        l_ins_con_error    VARCHAR2(2000);
    BEGIN
        FOR sup_rec IN lcu_ins_suppliers LOOP
            l_ins_sup_error := NULL;
    --===============================================================
    INSERT INTO ap_suppliers_int (
                vendor_interface_id,
                segment1,
                vendor_name,
                vendor_name_alt,
                last_update_date,
                last_updated_by,
                last_update_login,
                creation_date,
                created_by,
                terms_id,
                terms_name,
                pay_group_lookup_code,
                payment_priority,
                invoice_currency_code,
                payment_currency_code,
                invoice_amount_limit,
                payment_method_code,
                exclusive_payment_flag,
                attribute1)    --DFF1
                VALUES (
                ap_suppliers_int_s.NEXTVAL,
                NULL,-- sup_rec.supplier_id,
                upper(sup_rec.supplier_name),
                upper(sup_rec.supplier_name_alt),
                sysdate,
                g_user_id,
                g_login_id,
                sysdate,
                g_user_id,
                sup_rec.terms_id,
                sup_rec.terms_name,
                sup_rec.pay_group,
                sup_rec.payment_priority,
                sup_rec.invoice_currency,
                sup_rec.payment_currency,
                sup_rec.invoice_amount_limit,
                sup_rec.payment_method,
                sup_rec.pay_alone_flag,
                sup_rec.attribute1);                  --DFF1
                                       
            UPDATE xxap_suppliers_stg
            SET
                status_flag = 'C'
            WHERE
                ROWID = sup_rec.rowid;
            --- loop for inserting sites begins--
            FOR sit_rec IN lcu_ins_sites(sup_rec.supplier_number) LOOP
                l_ins_sit_error := NULL;
                BEGIN
                    INSERT INTO ap_supplier_sites_int (
                        vendor_interface_id,
                        vendor_site_interface_id,
                        last_update_date,
                        last_updated_by,
                        last_update_login,
                        vendor_id,
                        vendor_site_code,
                        vendor_site_code_alt,
                        creation_date,
                        created_by,
                        purchasing_site_flag,
                        rfq_only_site_flag,
                        primary_pay_site_flag,
                        address_line1,
                        address_line2,
                        address_line3,
                        address_line4,
                        city,
                        zip,
                        province,
                        country,
                        area_code,
                        phone,
                        fax,
                        fax_area_code,
                        telex,
                        payment_method_code,
                        pay_group_lookup_code,
                        payment_priority,
                        terms_id,
                        terms_name,
                        invoice_amount_limit,
                        invoice_currency_code,
                        payment_currency_code,
                        org_id,
                        email_address,
                        import_request_id,
                        status,
                        pay_site_flag,
                        exclusive_payment_flag,
                        hold_unmatched_invoices_flag,
                        create_debit_memo_flag,
                        tolerance_id
                    ) VALUES (
                        ap_suppliers_int_s.CURRVAL,
                        ap_supplier_sites_int_s.NEXTVAL,
                        sysdate,
                        g_user_id,
                        g_login_id,
                        sit_rec.supplier_number,
                        sit_rec.site_name,
                        sit_rec.site_name_alt,
                        sysdate,
                        g_user_id,
                        sit_rec.purchasing_site_flag,
                        sit_rec.rfq_only_site_flag,
                        sit_rec.primary_pay_flag,
                        sit_rec.address_line1,
                        sit_rec.address_line2,
                        sit_rec.address_line3,
                        sit_rec.address_line4,
                        sit_rec.city,
                        sit_rec.zip,
                        sit_rec.state,
                        sit_rec.country_code,
                        sit_rec.area_code,
                        sit_rec.phone,
                        sit_rec.fax,
                        sit_rec.fax_area_code,
                        sit_rec.telex,
                        sit_rec.payment_method,
                        sit_rec.pay_group,
                        sit_rec.payment_priority,
                        sit_rec.terms_id,
                        sit_rec.terms_name,
                        sit_rec.invoice_amount_limit,
                        sit_rec.invoice_currency,
                        sit_rec.payment_currency,
                        sit_rec.org_id,
                        sit_rec.email_address,
                        NULL,
                        NULL,
                        sit_rec.pay_site_flag,
                        sit_rec.pay_alone_flag,
                        sit_rec.hold_unmatched_invoices_flag,
                        sit_rec.create_debit_memo_flag,
                        sit_rec.tolerance_id
                    );

                    FOR con_rec IN lcu_ins_contacts(sit_rec.supplier_number, sit_rec.site_name) LOOP
                        l_ins_con_error := NULL;
                --=============================================
                                                 INSERT INTO ap_sup_site_contact_int (
                            vendor_interface_id,
                            vendor_contact_interface_id,
                            last_update_date,
                            last_updated_by,
                            vendor_id,
                            vendor_site_code,
                            org_id,
                            last_update_login,
                            creation_date,
                            created_by,
                            first_name,
                            middle_name,
                            last_name,
                            area_code,
                            phone,
                            email_address,
                            url,
                            fax_area_code,
                            fax
                        ) VALUES (
                            ap_suppliers_int_s.CURRVAL,
                            ap_sup_site_contact_int_s.NEXTVAL,
                            sysdate,
                            g_user_id,
                            con_rec.supplier_number,
                            con_rec.site_name,
                            con_rec.org_id,
                            g_login_id,
                            sysdate,
                            g_user_id,
                            con_rec.cont_first_name,
                            con_rec.cont_mid_name,
                            con_rec.cont_last_name,
                            con_rec.area_code,
                            con_rec.phone,
                            con_rec.email_address,
                            con_rec.url,
                            con_rec.fax_area_code,
                            con_rec.fax
                        );
              --================================================
                                     UPDATE xxap_sup_site_contact_stg
                        SET
                            status_flag = 'C'
                        WHERE
                            ROWID = con_rec.rowid;

                    END LOOP;
     --END LOOP;
                        END;
                 --=============================
                                 UPDATE xxap_sup_site_contact_stg con
                SET
                    status_flag = 'C'
                WHERE
                        con.status_flag = 'V'
                    AND con.site_name = sit_rec.site_name
                    AND con.supplier_number = sit_rec.supplier_number;

                UPDATE xxap_supplier_sites_stg
                SET
                    status_flag = 'C'
                WHERE
                    ROWID = sit_rec.rowid;

            END LOOP;

        END LOOP;
    END xxap_sup_site_con_insert_prc;
----------------------------------------  main procedure ------------------------------------------------------
        PROCEDURE xxap_suppliers_conv_main_prc (
        errbuf   OUT  VARCHAR2,
        retcode  OUT  VARCHAR2
    ) IS
    BEGIN
     -- Calling the  validate procedure
           xxap_sup_sit_con_val_prc;
     -- Calling the Insert Procedure
               xxap_sup_site_con_insert_prc;
        fnd_file.put_line(fnd_file.output, 'Number of Records found     for Suppliers  : ' || g_supplier_found);
        fnd_file.put_line(fnd_file.output, 'Number of Records processed for Suppliers      : ' || g_supplier_processed);
        fnd_file.put_line(fnd_file.output, 'Number of Records rejected  for Suppliers      : ' || g_supplier_rejected);
        fnd_file.put_line(fnd_file.output, 'Number of Records found     for Sites              : ' || g_site_found);
        fnd_file.put_line(fnd_file.output, 'Number of Records processed for Sites       : ' || g_site_processed);
        fnd_file.put_line(fnd_file.output, 'Number of Records rejected  for Sites       : ' || g_site_rejected);
        fnd_file.put_line(fnd_file.output, 'Number of Records found     for Contacts       : ' || g_contact_found);
        fnd_file.put_line(fnd_file.output, 'Number of Records processed for Contacts       : ' || g_contact_processed);
        fnd_file.put_line(fnd_file.output, 'Number of Records rejected  for Contacts       : ' || g_contact_rejected);
        COMMIT;
    END xxap_suppliers_conv_main_prc;

END xxap_suppliers_pkg;
/