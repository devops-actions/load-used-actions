import moment from 'moment'

export default function GetDateFormatted(date: Date): string {
  return moment(date).format('YYYYMMDD_HHmm')
}
