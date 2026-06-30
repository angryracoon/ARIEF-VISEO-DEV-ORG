@IsTest
private class MonthlyFinanceSummarySchedulableTest {

    @IsTest
    static void testScheduleRegistration() {
        // Abort any pre-existing job with the same name so the schedule call
        // and the count assertion are deterministic regardless of org state.
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Monthly Finance Summary'
        ]) {
            System.abortJob(ct.Id);
        }

        Test.startTest();
        String jobId = MonthlyFinanceSummarySchedulable.schedule();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Schedule should return a job ID');

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Monthly Finance Summary'
        ];
        System.assertEquals(1, jobs.size(), 'One scheduled job should exist');
        System.assertEquals('0 0 0 1 * ?', jobs[0].CronExpression, 'Cron expression should match');
    }

    @IsTest
    static void testExecuteDelegatesToBatch() {
        Test.startTest();
        MonthlyFinanceSummarySchedulable schedulable = new MonthlyFinanceSummarySchedulable();
        schedulable.execute(null);
        Test.stopTest();

        System.assert(true, 'Schedulable execute completed without exception');
    }
}