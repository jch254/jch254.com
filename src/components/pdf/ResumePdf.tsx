/**
 * PDF rendering of the resume, generated at build time by src/pages/resume.pdf.ts.
 * Content comes from src/data/resume.ts — edit that, not this layout.
 */
import { Document, Page, Text, View, Link, StyleSheet } from '@react-pdf/renderer';
import { resume } from '../../data/resume';

const accent = '#1DB954';
const text = '#1a1a2e';
const muted = '#55556b';

const styles = StyleSheet.create({
  page: {
    fontFamily: 'Helvetica',
    fontSize: 9.5,
    color: text,
    paddingVertical: 40,
    paddingHorizontal: 48,
    lineHeight: 1.45,
  },
  name: {
    fontSize: 22,
    fontFamily: 'Helvetica-Bold',
    lineHeight: 1.2,
    marginBottom: 4,
  },
  contactRow: {
    fontSize: 9,
    color: muted,
    marginBottom: 2,
  },
  link: {
    color: accent,
    textDecoration: 'none',
  },
  section: {
    marginTop: 14,
  },
  sectionTitle: {
    fontSize: 12,
    fontFamily: 'Helvetica-Bold',
    color: text,
    borderBottomWidth: 1,
    borderBottomColor: accent,
    paddingBottom: 2,
    marginBottom: 6,
  },
  paragraph: {
    marginBottom: 4,
  },
  skillRow: {
    marginBottom: 2,
  },
  bold: {
    fontFamily: 'Helvetica-Bold',
  },
  entry: {
    marginBottom: 8,
  },
  role: {
    fontSize: 10.5,
    fontFamily: 'Helvetica-Bold',
  },
  meta: {
    fontSize: 9,
    color: muted,
    marginBottom: 2,
  },
  bulletRow: {
    flexDirection: 'row',
    marginBottom: 1,
  },
  bulletGlyph: {
    width: 10,
    color: accent,
  },
  bulletText: {
    flex: 1,
  },
});

function Bullets({ items }: { items: string[] }) {
  return (
    <View>
      {items.map((item) => (
        <View key={item} style={styles.bulletRow}>
          <Text style={styles.bulletGlyph}>•</Text>
          <Text style={styles.bulletText}>{item}</Text>
        </View>
      ))}
    </View>
  );
}

export default function ResumePdf() {
  return (
    <Document
      title={`${resume.name} — Resume`}
      author={resume.name}
      subject="Resume"
    >
      <Page size="A4" style={styles.page}>
        {/* Header */}
        <Text style={styles.name}>{resume.name}</Text>
        <Text style={styles.contactRow}>{resume.location}</Text>
        <Text style={styles.contactRow}>
          <Link src={`mailto:${resume.email}`} style={styles.link}>{resume.email}</Link>
          {'   ·   '}
          <Link src={resume.website} style={styles.link}>jch254.com</Link>
          {'   ·   '}
          <Link src={resume.linkedin} style={styles.link}>linkedin.com/in/jch254</Link>
          {'   ·   '}
          <Link src={resume.github} style={styles.link}>github.com/jch254</Link>
        </Text>

        {/* Summary */}
        <View style={styles.section}>
          {resume.summary.map((para) => (
            <Text key={para} style={styles.paragraph}>{para}</Text>
          ))}
        </View>

        {/* Skills */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Skills</Text>
          {resume.skills.map((skill) => (
            <Text key={skill.label} style={styles.skillRow}>
              <Text style={styles.bold}>{skill.label}: </Text>
              {skill.items}
            </Text>
          ))}
        </View>

        {/* Experience */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Experience</Text>
          {resume.experience.map((entry) => (
            <View key={`${entry.role}-${entry.dates}`} style={styles.entry} wrap={false}>
              <Text style={styles.role}>{entry.role}</Text>
              <Text style={styles.meta}>
                {entry.org && (
                  entry.orgUrl
                    ? <Link src={entry.orgUrl} style={styles.link}>{entry.org}</Link>
                    : <Text>{entry.org}</Text>
                )}
                {entry.org ? ' · ' : ''}
                {[entry.location, entry.dates].join(' · ')}
              </Text>
              {entry.bullets && <Bullets items={entry.bullets} />}
              {entry.paragraph && <Text>{entry.paragraph}</Text>}
            </View>
          ))}
        </View>

        {/* Early Career */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Early Career Highlights</Text>
          {resume.earlyCareer.map((entry) => (
            <Text key={entry.title} style={styles.paragraph}>
              <Text style={styles.bold}>{entry.title} — </Text>
              {entry.description}
            </Text>
          ))}
        </View>

        {/* Education */}
        <View style={styles.section} wrap={false}>
          <Text style={styles.sectionTitle}>Education</Text>
          <View style={styles.entry}>
            <Text style={styles.role}>{resume.education.degree}</Text>
            <Text style={styles.meta}>
              {[resume.education.org, resume.education.location, resume.education.dates].join(' · ')}
            </Text>
            <Bullets items={resume.education.bullets} />
          </View>
        </View>

        {/* Achievements */}
        <View style={styles.section} wrap={false}>
          <Text style={styles.sectionTitle}>Achievements &amp; Awards</Text>
          <Bullets items={resume.achievements} />
        </View>

        {/* Personal */}
        <View style={styles.section} wrap={false}>
          <Text style={styles.sectionTitle}>Personal</Text>
          <Text>{resume.personal}</Text>
        </View>

        {/* References */}
        <View style={styles.section} wrap={false}>
          <Text style={styles.sectionTitle}>References</Text>
          <Text>References available on request.</Text>
        </View>
      </Page>
    </Document>
  );
}
