/**
 * @class        PreventCloseDateChangeAfterClosedWonTest
 * @description  Tests the Prevent_CloseDate_Change_After_ClosedWon validation rule
 *               on the Opportunity object. Covers: non-admin blocked from changing
 *               Close Date after Closed Won, admin exempt, other-field updates
 *               allowed, and bulk blocking of 5 records.
 * @author       Arief Gunawan
 * @date         2026-06-26
 * @see          Prevent_CloseDate_Change_After_ClosedWon (Validation Rule)
 */
@isTest
private class PreventCloseDateChangeAfterClosedWonTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createUser('Standard User', true);
    }

    // ─── Positive Tests ───────────────────────────────────────────────────

    /**
     * @description  Verifies that a non-admin user CAN change Close Date while the
     *               Opportunity stage is not yet Closed Won.
     */
    @isTest
    static void shouldAllowCloseDateChange_WhenStageIsNotClosedWon() {
        // Given
        User standardUser = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Standard User'
            AND Username LIKE '%@example.com.test'
            LIMIT 1
        ];

        System.runAs(standardUser) {
            Opportunity opp = TestDataFactory.createOpportunity('Prospecting', Date.today().addDays(30), true);

            // When
            Test.startTest();
            opp.CloseDate = Date.today().addDays(60);
            update opp;
            Test.stopTest();

            // Then
            Opportunity updated = [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id];
            Assert.areEqual(
                Date.today().addDays(60),
                updated.CloseDate,
                'Non-admin should be able to change Close Date when stage is not Closed Won.'
            );
        }
    }

    /**
     * @description  Verifies that a System Administrator CAN change Close Date even
     *               after the Opportunity is Closed Won (admin exemption).
     */
    @isTest
    static void shouldAllowCloseDateChange_WhenAdminAndClosedWon() {
        // Given
        Opportunity opp = TestDataFactory.createOpportunity('Closed Won', Date.today(), true);

        // When
        Test.startTest();
        opp.CloseDate = Date.today().addDays(30);
        update opp;
        Test.stopTest();

        // Then
        Opportunity updated = [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual(
            Date.today().addDays(30),
            updated.CloseDate,
            'System Administrator should be exempt and able to change Close Date after Closed Won.'
        );
    }

    /**
     * @description  Verifies that a non-admin user CAN update other fields (e.g. Name)
     *               on a Closed Won Opportunity without touching Close Date.
     */
    @isTest
    static void shouldAllowOtherFieldChange_WhenNonAdminAndClosedWon() {
        // Given
        User standardUser = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Standard User'
            AND Username LIKE '%@example.com.test'
            LIMIT 1
        ];

        System.runAs(standardUser) {
            Opportunity opp = TestDataFactory.createOpportunity('Closed Won', Date.today(), true);

            // When
            Test.startTest();
            opp.Name = 'Updated Opportunity Name';
            update opp;
            Test.stopTest();

            // Then
            Opportunity updated = [SELECT Name, CloseDate FROM Opportunity WHERE Id = :opp.Id];
            Assert.areEqual(
                'Updated Opportunity Name',
                updated.Name,
                'Non-admin should be able to update other fields on a Closed Won Opportunity.'
            );
            Assert.areEqual(
                Date.today(),
                updated.CloseDate,
                'Close Date should remain unchanged when another field is updated.'
            );
        }
    }

    // ─── Negative Tests ───────────────────────────────────────────────────

    /**
     * @description  Verifies that a non-admin user CANNOT change Close Date after the
     *               Opportunity reaches Closed Won. Expects a DmlException with the
     *               exact validation rule error message.
     */
    @isTest
    static void shouldBlockCloseDateChange_WhenNonAdminAndClosedWon() {
        // Given
        User standardUser = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Standard User'
            AND Username LIKE '%@example.com.test'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        System.runAs(standardUser) {
            Opportunity opp = TestDataFactory.createOpportunity('Closed Won', Date.today(), true);

            // When
            Test.startTest();
            try {
                opp.CloseDate = Date.today().addDays(30);
                update opp;
                Assert.fail('Expected DmlException for Close Date change after Closed Won.');
            } catch (DmlException e) {
                exceptionThrown = true;
                Assert.isTrue(
                    e.getMessage().contains('Close Date cannot be modified after the Opportunity is Closed Won.'),
                    'Expected VR error message. Got: ' + e.getMessage()
                );
            }
            Test.stopTest();
        }

        Assert.isTrue(exceptionThrown, 'DmlException should have been thrown for non-admin changing Close Date after Closed Won.');
    }

    /**
     * @description  Verifies that the validation rule fires correctly on a bulk update
     *               when a non-admin user attempts to change Close Date on multiple
     *               Closed Won Opportunities at once.
     */
    @isTest
    static void shouldBlockBulkCloseDateChange_WhenNonAdminAndClosedWon() {
        // Given
        User standardUser = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Standard User'
            AND Username LIKE '%@example.com.test'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        System.runAs(standardUser) {
            List<Opportunity> opps = TestDataFactory.createOpportunities(5, 'Closed Won', Date.today(), true);
            for (Opportunity opp : opps) {
                opp.CloseDate = Date.today().addDays(30);
            }

            // When
            Test.startTest();
            try {
                update opps;
                Assert.fail('Expected DmlException for bulk Close Date change after Closed Won.');
            } catch (DmlException e) {
                exceptionThrown = true;
                Assert.isTrue(
                    e.getMessage().contains('Close Date cannot be modified after the Opportunity is Closed Won.'),
                    'Expected VR error message on bulk update. Got: ' + e.getMessage()
                );
            }
            Test.stopTest();
        }

        Assert.isTrue(exceptionThrown, 'DmlException should have been thrown for bulk non-admin Close Date change after Closed Won.');
    }
}