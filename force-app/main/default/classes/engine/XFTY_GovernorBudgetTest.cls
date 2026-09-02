/**
 * Proves `XFTY_GovernorBudget` - the "generation ate a large share of a governor
 * limit" warning, its `XFTY_Settings__c` thresholds, and its off switch. Uses DML
 * rows as the counter, with the warn thresholds turned right down so a small
 * `insert` crosses them (a full-size bulk insert is needlessly slow on CI and can
 * exhaust the CPU limit before the assertion runs). Real DML, so `System.runAs`.
 *
 * The budget is constructed and read inside `Test.startTest()` / `Test.stopTest()`
 * so its baseline, the work it measures, and the reading all share one limit
 * context (`stopTest()` restores the outer limits).
 */
@IsTest
private class XFTY_GovernorBudgetTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testWarnings_afterACheapInsert_areEmpty() {
        // Arrange
        List<String> warnings;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
            insert new Account(Name = 'One');
            warnings = budget.warnings();
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(warnings.isEmpty(), String.valueOf(warnings));
    }

    @IsTest
    static void testWarnings_pastTheSoftThreshold_flagTheCounterAsALargePart() {
        assertSoftThresholdWarning(10, 1500);
    }

    @IsTest
    static void testWarnings_whenAnInsertIsUnderTheDefaultButOverACustomSoftThreshold_flagIt() {
        assertSoftThresholdWarning(5, 800);
    }

    @IsTest
    static void testWarnings_pastTheHardThreshold_flagTheCounterAsMostOfTheLimit() {
        // Arrange - hard threshold at 10%; 1 500 rows is 15%, past it
        insert new XFTY_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                LimitWarnSoftPercent__c = 5,
                LimitWarnHardPercent__c = 10
        );
        String dmlRowWarning;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
            insert accountsNamed(1500);
            dmlRowWarning = warningFor('DML rows', budget);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(dmlRowWarning.contains('most of'), dmlRowWarning);
    }

    @IsTest
    static void testWarnings_whenWarningsAreDisabled_areEmptyEvenPastTheThreshold() {
        // Arrange - past the (lowered) soft threshold, but warnings are switched off
        insert new XFTY_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                LimitWarningsDisabled__c = true,
                LimitWarnSoftPercent__c = 5
        );
        List<String> warnings;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
            insert accountsNamed(1500);
            warnings = budget.warnings();
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(warnings.isEmpty(), 'LimitWarningsDisabled__c silences the warning');
    }

    @IsTest
    static void testWarnIfExpensive_whenWarningsAreDisabled_runsCleanly() {
        // Arrange
        insert new XFTY_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                LimitWarningsDisabled__c = true,
                LimitWarnSoftPercent__c = 5
        );

        // Act
        Exception thrown;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
            insert accountsNamed(1500);
            try {
                budget.warnIfExpensive();
            } catch (Exception ex) {
                thrown = ex;
            }
            Test.stopTest();
        }

        // Assert
        Assert.isNull(thrown, 'warnIfExpensive() is a clean no-op when warnings are disabled');
    }

    static void assertSoftThresholdWarning(Integer softPercent, Integer rowCount) {
        // Arrange
        insert new XFTY_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), LimitWarnSoftPercent__c = softPercent);
        String dmlRowWarning;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
            insert accountsNamed(rowCount);
            dmlRowWarning = warningFor('DML rows', budget);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(dmlRowWarning.contains('a large part of'), dmlRowWarning);
    }

    private static String warningFor(String counter, XFTY_GovernorBudget budget) {
        for (String warning : budget.warnings()) {
            if (warning.contains(counter)) {
                return warning;
            }
        }
        return '';
    }

    private static List<Account> accountsNamed(Integer howMany) {
        List<Account> newAccounts = new List<Account>();
        for (Integer i = 0; i < howMany; i++) {
            newAccounts.add(new Account(Name = 'Bulk ' + i));
        }
        return newAccounts;
    }
}
