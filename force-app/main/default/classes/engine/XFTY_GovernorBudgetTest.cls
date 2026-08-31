/**
 * Coverage for `XFTY_GovernorBudget` - the "generation ate a large share of a
 * governor limit" warning, its `XFTY_Settings__c` thresholds, and its off switch.
 * Uses DML rows (10 000 limit) as the counter that is cheap to push with one
 * `insert`.
 */
@IsTest
private class XFTY_GovernorBudgetTest {
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void cheapGenerationProducesNoWarnings() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        insert new Account(Name = 'One');

        Assert.isTrue(budget.warnings().isEmpty(), budget.warnings().toString());
    }

    @IsTest
    static void pastTheSoftThresholdWarns() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(6000);   // 6000 / 10000 DML rows -> past the 50% default
        }

        Assert.isTrue(warningFor('DML rows', budget).contains('a large part of'), budget.warnings().toString());
    }

    @IsTest
    static void pastTheHardThresholdWarnsHarder() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(9000);   // 9000 / 10000 DML rows -> past the 80% default
        }

        Assert.isTrue(warningFor('DML rows', budget).contains('most of'), budget.warnings().toString());
    }

    @IsTest
    static void aCustomSoftThresholdIsHonoured() {
        insert new XFTY_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), LimitWarnSoftPercent__c = 20);

        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(3000);   // 3000 / 10000 = 30% -> under the 50% default, over a 20% setting
        }

        Assert.isTrue(warningFor('DML rows', budget).contains('a large part of'), budget.warnings().toString());
    }

    @IsTest
    static void disabledSuppressesEveryWarning() {
        insert new XFTY_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), LimitWarningsDisabled__c = true);

        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(9000);
        }

        Assert.isTrue(budget.warnings().isEmpty(), 'LimitWarningsDisabled__c silences the warning');
        budget.warnIfExpensive();   // must still run cleanly
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
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < howMany; i++) {
            accounts.add(new Account(Name = 'Bulk ' + i));
        }
        return accounts;
    }
}
